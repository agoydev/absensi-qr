class SchoolClass {
  final int id;
  final String name;

  const SchoolClass({required this.id, required this.name});

  factory SchoolClass.fromMap(Map<String, dynamic> map) {
    return SchoolClass(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
    );
  }
}

class Subject {
  final int id;
  final String code;
  final String name;

  const Subject({required this.id, required this.code, required this.name});

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: (map['id'] as num).toInt(),
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}

class Teacher {
  final int id;
  final String name;

  const Teacher({required this.id, required this.name});

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
    );
  }
}

class Schedule {
  final int id;
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;
  final int teacherId;
  final String teacherName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int lateAfterMinutes;
  final String schoolYear;

  const Schedule({
    required this.id,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.lateAfterMinutes,
    required this.schoolYear,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;

    return Schedule(
      id: number('id'),
      classId: number('class_id'),
      className: map['class_name']?.toString() ?? '',
      subjectId: number('subject_id'),
      subjectName: map['subject_name']?.toString() ?? '',
      teacherId: number('teacher_id'),
      teacherName: map['teacher_name']?.toString() ?? '',
      dayOfWeek: number('day_of_week'),
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      lateAfterMinutes: number('late_after_minutes'),
      schoolYear: map['school_year']?.toString() ?? '',
    );
  }
}
