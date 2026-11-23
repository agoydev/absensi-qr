import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'api_service.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/session.dart';
import '../models/schedule.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'absensi_qr.db';
  static const _dbVersion = 3;

  Database? _database;
  final StreamController<void> _dataChangesController =
      StreamController<void>.broadcast();
  final List<Student> _memoryStudents = [];
  final List<Attendance> _memoryAttendance = [];
  int _studentIdCounter = 1;
  int _attendanceIdCounter = 1;

  Stream<void> get dataChanges => _dataChangesController.stream;

  bool get _useApi => ApiService.instance.isConfigured;

  Future<void> init() async {
    if (kIsWeb) {
      return;
    }

    await database;
  }

  Future<Database> get database async {
    // Priority 2: Web gunakan in-memory
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite native tidak digunakan di web. Gunakan metode memory fallback.',
      );
    }

    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            nis TEXT NOT NULL UNIQUE,
            class_name TEXT NOT NULL,
            qr_code TEXT NOT NULL UNIQUE,
            parent_name TEXT,
            parent_phone TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            student_name TEXT NOT NULL,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            status TEXT NOT NULL,
            session_id INTEGER,
            notes TEXT,
            recorded_by INTEGER,
            FOREIGN KEY (student_id) REFERENCES students(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE attendance ADD COLUMN session_id INTEGER',
          );
          await db.execute('ALTER TABLE attendance ADD COLUMN notes TEXT');
          await db.execute(
            'ALTER TABLE attendance ADD COLUMN recorded_by INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE students ADD COLUMN parent_name TEXT');
          await db.execute('ALTER TABLE students ADD COLUMN parent_phone TEXT');
        }
      },
    );
  }

  Future<List<Student>> getStudents() async {
    if (_useApi) {
      return ApiService.instance.getStudents();
    }

    if (kIsWeb) {
      final result =
          List<Student>.from(
              _memoryStudents,
            ) //pencarian siswa berdasarkan QR yang sudah dibuatkan
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      return result;
    }

    final db = await database;
    final result = await db.query('students', orderBy: 'name ASC');
    return result.map(Student.fromMap).toList();
  }

  Future<Student?> findStudentByQr(String qrCode) async {
    final normalizedCode = qrCode.trim();

    if (_useApi) {
      return ApiService.instance.findStudentByQr(normalizedCode);
    }

    if (kIsWeb) {
      for (final student in _memoryStudents) {
        if (student.qrCode == normalizedCode || student.nis == normalizedCode) {
          return student;
        }
      }
      return null;
    }

    final db = await database;
    final result = await db.query(
      'students',
      where: 'qr_code = ? OR nis = ?',
      whereArgs: [normalizedCode, normalizedCode],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Student.fromMap(result.first);
  }

  Future<int> insertStudent(Student student) async {
    if (_useApi) {
      final id = await ApiService.instance.insertStudent(student);
      _dataChangesController.add(null);
      return id;
    }

    if (kIsWeb) {
      final nisExists = _memoryStudents.any((item) => item.nis == student.nis);
      final qrExists = _memoryStudents.any(
        (item) => item.qrCode == student.qrCode,
      );
      if (nisExists || qrExists) {
        throw StateError('Duplicate student');
      }

      final newStudent = student.copyWith(id: _studentIdCounter++);
      _memoryStudents.add(newStudent);
      _dataChangesController.add(null);
      return newStudent.id ?? 0;
    }

    final db = await database; // Priority 3: Default gunakan SQLite
    final id = await db.insert('students', student.toMap());
    _dataChangesController.add(null);
    return id;
  }

  Future<int> updateStudent(Student student) async {
    if (_useApi) {
      final result = await ApiService.instance.updateStudent(student);
      _dataChangesController.add(null);
      return result;
    }

    if (kIsWeb) {
      final index = _memoryStudents.indexWhere((item) => item.id == student.id);
      if (index == -1) {
        return 0;
      }

      _memoryStudents[index] = student;
      _dataChangesController.add(null);
      return 1;
    }

    final db = await database;
    final result = await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
    _dataChangesController.add(null);
    return result;
  } //untuk simpan absensi.

  Future<int> deleteStudent(int id) async {
    if (_useApi) {
      final result = await ApiService.instance.deleteStudent(id);
      _dataChangesController.add(null);
      return result;
    }

    if (kIsWeb) {
      _memoryAttendance.removeWhere((item) => item.studentId == id);
      final before = _memoryStudents.length;
      _memoryStudents.removeWhere((item) => item.id == id);
      _dataChangesController.add(null);
      return before - _memoryStudents.length;
    }

    final db = await database;
    await db.delete('attendance', where: 'student_id = ?', whereArgs: [id]);
    final result = await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    _dataChangesController.add(null);
    return result;
  }

  Future<bool> hasAttendanceToday(int studentId, String date) async {
    if (_useApi) {
      return ApiService.instance.hasAttendanceToday(studentId, date);
    }

    if (kIsWeb) {
      return _memoryAttendance.any(
        (item) => item.studentId == studentId && item.date == date,
      );
    }

    final db = await database;
    final result = await db.query(
      'attendance',
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, date],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<bool> hasAttendanceForSession(int studentId, int sessionId) async {
    if (_useApi) {
      return ApiService.instance.hasAttendanceForSession(studentId, sessionId);
    }
    if (kIsWeb) {
      return _memoryAttendance.any(
        (item) => item.studentId == studentId && item.sessionId == sessionId,
      );
    }
    final db = await database;
    final result = await db.query(
      'attendance',
      where: 'student_id = ? AND session_id = ?',
      whereArgs: [studentId, sessionId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<AttendanceSession>> getSessions({String? date}) async {
    if (!_useApi) {
      return const [];
    }

    return ApiService.instance.getSessions(date: date);
  }

  Future<List<SchoolClass>> getClasses() async {
    if (!_useApi) return const [];
    return ApiService.instance.getClasses();
  }

  Future<void> createClass({
    required String name,
    required String gradeLevel,
    required String major,
    required String schoolYear,
  }) async {
    if (!_useApi) {
      throw StateError('Pengelolaan kelas membutuhkan koneksi ke API cloud.');
    }

    await ApiService.instance.createClass(
      name: name,
      gradeLevel: gradeLevel,
      major: major,
      schoolYear: schoolYear,
    );
  }

  Future<void> createUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (!_useApi) {
      throw StateError('Pengelolaan akun membutuhkan koneksi ke API cloud.');
    }
    await ApiService.instance.createUser(
      name: name,
      username: username,
      password: password,
      role: role,
    );
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    if (!_useApi) {
      throw StateError('Daftar akun membutuhkan koneksi ke API cloud.');
    }
    return ApiService.instance.getUsers();
  }

  Future<List<Subject>> getSubjects() async {
    if (!_useApi) return const [];
    return ApiService.instance.getSubjects();
  }

  Future<void> createSubject({
    required String code,
    required String name,
  }) async {
    if (!_useApi) {
      throw StateError(
        'Pengelolaan mata pelajaran membutuhkan koneksi ke API cloud.',
      );
    }
    await ApiService.instance.createSubject(code: code, name: name);
  }

  Future<List<Teacher>> getTeachers() async {
    if (!_useApi) return const [];
    return ApiService.instance.getTeachers();
  }

  Future<List<Schedule>> getSchedules() async {
    if (!_useApi) return const [];
    return ApiService.instance.getSchedules();
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
    if (!_useApi) {
      throw StateError('Pengelolaan jadwal membutuhkan koneksi ke API cloud.');
    }
    await ApiService.instance.createSchedule(
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      lateAfterMinutes: lateAfterMinutes,
      schoolYear: schoolYear,
    );
  }

  Future<void> updateSessionStatus({
    required int sessionId,
    required String status,
    int? userId,
  }) async {
    if (!_useApi) {
      throw StateError('Sesi pembelajaran membutuhkan koneksi ke API cloud.');
    }
    await ApiService.instance.updateSessionStatus(
      sessionId: sessionId,
      status: status,
      userId: userId,
    );
    _dataChangesController.add(null);
  }

  Future<int> insertAttendance(Attendance attendance) async {
    if (_useApi) {
      final id = await ApiService.instance.insertAttendance(attendance);
      _dataChangesController.add(null);
      return id;
    }

    if (kIsWeb) {
      final newAttendance = Attendance(
        id: _attendanceIdCounter++,
        studentId: attendance.studentId,
        studentName: attendance.studentName,
        date: attendance.date,
        time: attendance.time,
        status: attendance.status,
      );
      _memoryAttendance.add(newAttendance);
      _dataChangesController.add(null);
      return newAttendance.id ?? 0;
    }

    final db = await database;
    final id = await db.insert('attendance', attendance.toMap());
    _dataChangesController.add(null);
    return id;
  }

  Future<List<Attendance>> getAttendance({String? date}) async {
    if (_useApi) {
      return ApiService.instance.getAttendance(date: date);
    }

    if (kIsWeb) {
      final result = date == null
          ? List<Attendance>.from(_memoryAttendance)
          : _memoryAttendance.where((item) => item.date == date).toList();
      result.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return b.time.compareTo(a.time);
      });
      return result;
    }

    final db = await database;

    final result = await db.query(
      'attendance',
      where: date == null ? null : 'date = ?',
      whereArgs: date == null ? null : [date],
      orderBy: 'date DESC, time DESC',
    );

    return result.map(Attendance.fromMap).toList();
  }

  Future<int> updateAttendance(Attendance attendance) async {
    if (_useApi) {
      final result = await ApiService.instance.updateAttendance(attendance);
      _dataChangesController.add(null);
      return result;
    }

    if (kIsWeb) {
      final index = _memoryAttendance.indexWhere(
        (item) => item.id == attendance.id,
      );
      if (index == -1) return 0;
      _memoryAttendance[index] = attendance;
      _dataChangesController.add(null);
      return 1;
    }

    final db = await database;
    final result = await db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
    _dataChangesController.add(null);
    return result;
  }
}
