class Student {
  final int? id;
  final String name;
  final String nis;
  final String className;
  final String qrCode;
  final String parentName;
  final String parentPhone;

  const Student({
    this.id,
    required this.name,
    required this.nis,
    required this.className,
    required this.qrCode,
    this.parentName = '',
    this.parentPhone = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nis': nis,
      'class_name': className,
      'qr_code': qrCode,
      'parent_name': parentName,
      'parent_phone': parentPhone,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      nis: map['nis'] as String,
      className: map['class_name'] as String,
      qrCode: map['qr_code'] as String,
      parentName: map['parent_name']?.toString() ?? '',
      parentPhone: map['parent_phone']?.toString() ?? '',
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? nis,
    String? className,
    String? qrCode,
    String? parentName,
    String? parentPhone,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      nis: nis ?? this.nis,
      className: className ?? this.className,
      qrCode: qrCode ?? this.qrCode,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
    );
  }
}
