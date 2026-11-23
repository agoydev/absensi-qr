import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/database_service.dart';

class ScheduleScreen extends StatefulWidget {
  static const routeName = '/schedules';

  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<Schedule>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _schedulesFuture = DatabaseService.instance.getSchedules();
  }

  Future<void> _showCreateDialog() async {
    final classes = await DatabaseService.instance.getClasses();
    final subjects = await DatabaseService.instance.getSubjects();
    final teachers = await DatabaseService.instance.getTeachers();

    if (!mounted) return;
    if (classes.isEmpty || subjects.isEmpty || teachers.isEmpty) {
      _showMessage(
        'Data kelas, mata pelajaran, dan guru harus tersedia lebih dulu.',
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ScheduleDialog(
        classes: classes,
        subjects: subjects,
        teachers: teachers,
        onError: _showMessage,
      ),
    );

    if (saved == true && mounted) {
      _reload();
      setState(() {});
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pembelajaran'),
        actions: [
          IconButton(onPressed: _showCreateDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<Schedule>>(
        future: _schedulesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat jadwal: ${snapshot.error}'),
            );
          }
          final schedules = snapshot.data ?? const [];
          if (schedules.isEmpty) {
            return const Center(child: Text('Belum ada jadwal pembelajaran.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              setState(() {});
              await _schedulesFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final item = schedules[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text('${item.className} - ${item.subjectName}'),
                    subtitle: Text(
                      '${_dayName(item.dayOfWeek)} | ${item.startTime} - ${item.endTime}\n'
                      'Guru: ${item.teacherName}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _dayName(int day) {
    const days = ['-', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return day >= 1 && day < days.length ? days[day] : 'Minggu';
  }
}

class _ScheduleDialog extends StatefulWidget {
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final List<Teacher> teachers;
  final ValueChanged<String> onError;

  const _ScheduleDialog({
    required this.classes,
    required this.subjects,
    required this.teachers,
    required this.onError,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _yearController;
  late final TextEditingController _lateController;
  late SchoolClass _selectedClass;
  late Subject _selectedSubject;
  late Teacher _selectedTeacher;
  int _day = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.classes.first;
    _selectedSubject = widget.subjects.first;
    _selectedTeacher = widget.teachers.first;
    _startController = TextEditingController(text: '07:30');
    _endController = TextEditingController(text: '09:00');
    _yearController = TextEditingController(text: '2026/2027');
    _lateController = TextEditingController(text: '15');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _yearController.dispose();
    _lateController.dispose();
    super.dispose();
  }

  String? _validateTime(String? value) {
    final valid = RegExp(r'^\d{2}:\d{2}$').hasMatch(value?.trim() ?? '');
    return valid ? null : 'Gunakan format HH:mm';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await DatabaseService.instance.createSchedule(
        classId: _selectedClass.id,
        subjectId: _selectedSubject.id,
        teacherId: _selectedTeacher.id,
        dayOfWeek: _day,
        startTime: '${_startController.text}:00',
        endTime: '${_endController.text}:00',
        lateAfterMinutes: int.parse(_lateController.text),
        schoolYear: _yearController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      widget.onError(error.toString());
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 460.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      title: const Text('Tambah Jadwal'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SchoolClass>(
                  initialValue: _selectedClass,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    isDense: true,
                  ),
                  items: widget.classes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      _selectedClass = value ?? _selectedClass,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Subject>(
                  initialValue: _selectedSubject,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mata pelajaran',
                    isDense: true,
                  ),
                  items: widget.subjects
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.code} - ${item.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      _selectedSubject = value ?? _selectedSubject,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Teacher>(
                  initialValue: _selectedTeacher,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Guru',
                    isDense: true,
                  ),
                  items: widget.teachers
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      _selectedTeacher = value ?? _selectedTeacher,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _day,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hari',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Senin')),
                    DropdownMenuItem(value: 2, child: Text('Selasa')),
                    DropdownMenuItem(value: 3, child: Text('Rabu')),
                    DropdownMenuItem(value: 4, child: Text('Kamis')),
                    DropdownMenuItem(value: 5, child: Text('Jumat')),
                    DropdownMenuItem(value: 6, child: Text('Sabtu')),
                  ],
                  onChanged: (value) => _day = value ?? _day,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: 'Jam mulai (HH:mm)',
                    isDense: true,
                  ),
                  validator: _validateTime,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'Jam selesai (HH:mm)',
                    isDense: true,
                  ),
                  validator: _validateTime,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lateController,
                  decoration: const InputDecoration(
                    labelText: 'Batas terlambat (menit)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? 'Masukkan angka'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Tahun ajaran',
                    isDense: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Wajib diisi'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
