import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/session.dart';
import '../models/schedule.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  bool get isConfigured => AppConfig.useApi;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = AppConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/auth/login'),
      headers: _headers(json: true),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('Login cloud gagal: ${response.statusCode}');
    }
    final payload = _decodeObject(response.body);
    final token = payload['token']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Respons login cloud tidak memiliki token.');
    }
    setToken(token);
    return payload;
  }

  Future<void> createUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      _uri('/users'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': name,
        'username': username,
        'password': password,
        'role': role,
      }),
    );
    if (response.statusCode != 201) {
      final payload = _decodeObject(response.body);
      throw Exception(
        payload['message']?.toString() ??
            'Gagal membuat akun: ${response.statusCode}',
      );
    }
  }

  Future<void> registerTeacher({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/auth/register'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': username.trim(),
        'username': username.trim(),
        'password': password,
      }),
    );
    if (response.statusCode != 201) {
      final payload = _decodeObject(response.body);
      throw Exception(
        payload['message']?.toString() ??
            'Gagal mendaftarkan akun: ${response.statusCode}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(_uri('/users'), headers: _headers());
    if (response.statusCode != 200) {
      final payload = _decodeObject(response.body);
      throw Exception(
        payload['message']?.toString() ??
            'Gagal memuat akun: ${response.statusCode}',
      );
    }
    return _decodeList(response.body);
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return const [];
  }

  Future<List<Student>> getStudents() async {
    final response = await http.get(_uri('/students'));
    if (response.statusCode != 200) {
      final payload = _decodeObject(response.body);
      throw Exception(
        payload['message']?.toString() ??
            'Gagal memuat siswa: ${response.statusCode}',
      );
    }

    return _decodeList(response.body).map(Student.fromMap).toList();
  }

  Future<Student?> findStudentByQr(String qrCode) async {
    final response = await http.get(
      _uri('/students/lookup', {'qr': qrCode.trim()}),
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception('Gagal mencari siswa: ${response.statusCode}');
    }

    return Student.fromMap(_decodeObject(response.body));
  }

  Future<int> insertStudent(Student student) async {
    final response = await http.post(
      _uri('/students'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(student.toMap()),
    );

    if (response.statusCode != 201) {
      throw Exception('Gagal menambah siswa: ${response.statusCode}');
    }

    final payload = _decodeObject(response.body);
    return payload['id'] as int? ?? 0;
  }

  Future<int> updateStudent(Student student) async {
    final id = student.id;
    if (id == null) {
      throw ArgumentError('Student id is required');
    }

    final response = await http.put(
      _uri('/students/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(student.toMap()),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengubah siswa: ${response.statusCode}');
    }

    return 1;
  }

  Future<int> deleteStudent(int id) async {
    final response = await http.delete(_uri('/students/$id'));
    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus siswa: ${response.statusCode}');
    }

    return 1;
  }

  Future<bool> hasAttendanceToday(int studentId, String date) async {
    final response = await http.get(
      _uri('/attendance/exists', {
        'studentId': studentId.toString(),
        'date': date,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal cek absensi: ${response.statusCode}');
    }

    final payload = _decodeObject(response.body);
    return payload['exists'] == true;
  }

  Future<bool> hasAttendanceForSession(int studentId, int sessionId) async {
    final response = await http.get(
      _uri('/attendance/exists', {
        'studentId': studentId.toString(),
        'sessionId': sessionId.toString(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal cek absensi sesi: ${response.statusCode}');
    }
    return _decodeObject(response.body)['exists'] == true;
  }

  Future<List<AttendanceSession>> getSessions({String? date}) async {
    final query = <String, String>{};
    if (date != null) query['date'] = date;
    final response = await http.get(
      _uri('/sessions', query.isEmpty ? null : query),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat sesi: ${response.statusCode}');
    }

    return _decodeList(response.body).map(AttendanceSession.fromMap).toList();
  }

  Future<List<SchoolClass>> getClasses() async {
    final response = await http.get(_uri('/classes'));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat kelas: ${response.statusCode}');
    }

    return _decodeList(response.body).map(SchoolClass.fromMap).toList();
  }

  Future<void> createClass({
    required String name,
    required String gradeLevel,
    required String major,
    required String schoolYear,
  }) async {
    final response = await http.post(
      _uri('/classes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'grade_level': gradeLevel,
        'major': major,
        'school_year': schoolYear,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Gagal membuat kelas: ${response.statusCode}');
    }
  }

  Future<List<Subject>> getSubjects() async {
    final response = await http.get(_uri('/subjects'));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat mata pelajaran: ${response.statusCode}');
    }

    return _decodeList(response.body).map(Subject.fromMap).toList();
  }

  Future<void> createSubject({
    required String code,
    required String name,
  }) async {
    final response = await http.post(
      _uri('/subjects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'name': name}),
    );
    if (response.statusCode != 201) {
      throw Exception('Gagal membuat mata pelajaran: ${response.statusCode}');
    }
  }

  Future<List<Teacher>> getTeachers() async {
    final response = await http.get(_uri('/teachers'));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat guru: ${response.statusCode}');
    }
    return _decodeList(response.body).map(Teacher.fromMap).toList();
  }

  Future<List<Schedule>> getSchedules() async {
    final response = await http.get(_uri('/schedules'));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat jadwal: ${response.statusCode}');
    }
    return _decodeList(response.body).map(Schedule.fromMap).toList();
  }

  Future<void> createSchedule({
    required int classId,
    required int subjectId,
    required int teacherId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required int lateAfterMinutes,
    required String schoolYear,
  }) async {
    final response = await http.post(
      _uri('/schedules'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'class_id': classId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'late_after_minutes': lateAfterMinutes,
        'school_year': schoolYear,
      }),
    );
    if (response.statusCode != 201) {
      final payload = _decodeObject(response.body);
      throw Exception(
        payload['message']?.toString() ??
            'Gagal membuat jadwal: ${response.statusCode}',
      );
    }
  }

  Future<void> updateSessionStatus({
    required int sessionId,
    required String status,
    int? userId,
  }) async {
    final response = await http.patch(
      _uri('/sessions/$sessionId/status'),
      headers: _headers(json: true),
      body: jsonEncode({'status': status, 'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal mengubah status sesi: ${response.statusCode}');
    }
  }

  Future<int> insertAttendance(Attendance attendance) async {
    final response = await http.post(
      _uri('/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(attendance.toMap()),
    );

    if (response.statusCode != 201) {
      throw Exception('Gagal simpan absensi: ${response.statusCode}');
    }

    final payload = _decodeObject(response.body);
    return payload['id'] as int? ?? 0;
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final id = attendance.id;
    if (id == null) {
      throw ArgumentError('Attendance id is required');
    }

    final response = await http.put(
      _uri('/attendance/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(attendance.toMap()),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal ubah absensi: ${response.statusCode}');
    }

    return 1;
  }

  Future<List<Attendance>> getAttendance({String? date}) async {
    final queryParameters = date == null
        ? null
        : <String, String>{'date': date};
    final response = await http.get(_uri('/attendance', queryParameters));

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat absensi: ${response.statusCode}');
    }

    return _decodeList(response.body).map(Attendance.fromMap).toList();
  }
}
