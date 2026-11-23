class Attendance {
  final int? id;
  final int? sessionId;
  final int studentId;
  final String studentName;
  final String date;
  final String time;
  final String status;
  final String? notes;
  final int? recordedBy;

  const Attendance({
    this.id,
    this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.time,
    required this.status,
    this.notes,
    this.recordedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'date': date,
      'time': time,
      'status': status,
      'notes': notes,
      'recorded_by': recordedBy,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      sessionId: (map['session_id'] as num?)?.toInt(),
      studentId: map['student_id'] as int,
      studentName: map['student_name'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      status: map['status'] as String,
      notes: map['notes']?.toString(),
      recordedBy: (map['recorded_by'] as num?)?.toInt(),
    );
  }
}
