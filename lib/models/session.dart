class AttendanceSession {
  final int id;
  final int scheduleId;
  final String sessionDate;
  final int meetingNumber;
  final String startAt;
  final String endAt;
  final String attendanceDeadline;
  final String status;
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;
  final int teacherId;
  final String teacherName;
  final int lateAfterMinutes;

  const AttendanceSession({
    required this.id,
    required this.scheduleId,
    required this.sessionDate,
    required this.meetingNumber,
    required this.startAt,
    required this.endAt,
    required this.attendanceDeadline,
    required this.status,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.lateAfterMinutes,
  });

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;

    return AttendanceSession(
      id: number('id'),
      scheduleId: number('schedule_id'),
      sessionDate: map['session_date']?.toString() ?? '',
      meetingNumber: number('meeting_number'),
      startAt: map['start_at']?.toString() ?? '',
      endAt: map['end_at']?.toString() ?? '',
      attendanceDeadline: map['attendance_deadline']?.toString() ?? '',
      status: map['status']?.toString() ?? 'scheduled',
      classId: number('class_id'),
      className: map['class_name']?.toString() ?? '',
      subjectId: number('subject_id'),
      subjectName: map['subject_name']?.toString() ?? '',
      teacherId: number('teacher_id'),
      teacherName: map['teacher_name']?.toString() ?? '',
      lateAfterMinutes: number('late_after_minutes'),
    );
  }

  bool get isOngoing => status == 'ongoing';
}
