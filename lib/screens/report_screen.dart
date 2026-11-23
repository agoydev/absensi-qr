import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/attendance.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ReportScreen extends StatefulWidget {
  static const routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Timer? _timer;
  List<_ReportItem> _reportItems = [];
  String? dateFilter;
  DateTime? dateFrom;
  DateTime? dateTo;
  String? classFilter;
  String? statusFilter;
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();

    // Auto-refresh every 30 seconds
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAttendance(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final attendanceData = await DatabaseService.instance.getAttendance();
    _students = await DatabaseService.instance.getStudents();
    final selectedDate = dateFilter;
    final studentById = {
      for (final student in _students)
        if (student.id != null) student.id!: student,
    };

    List<_ReportItem> items;
    if (selectedDate != null) {
      items = _buildDailyReportItems(
        students: _students,
        attendanceData: attendanceData,
        date: selectedDate,
      );
    } else {
      items = attendanceData
          .map(
            (attendance) => _ReportItem(
              attendanceId: attendance.id,
              studentId: attendance.studentId,
              studentName: attendance.studentName,
              className: studentById[attendance.studentId]?.className ?? '',
              date: attendance.date,
              time: attendance.time,
              status: attendance.status,
            ),
          )
          .toList();
    }

    items = items.where(_matchesFilters).toList();

    if (mounted) {
      setState(() {
        _reportItems = items;
        _isLoading = false;
      });
    }
  }

  List<_ReportItem> _buildDailyReportItems({
    required List<Student> students,
    required List<Attendance> attendanceData,
    required String date,
  }) {
    final attendanceByStudentId = <int, Attendance>{
      for (final item in attendanceData) item.studentId: item,
    };

    final items = students.map((student) {
      final attendance = attendanceByStudentId[student.id];
      if (attendance != null) {
        return _ReportItem(
          attendanceId: attendance.id,
          studentName: student.name,
          studentId: student.id,
          className: student.className,
          date: attendance.date,
          time: attendance.time,
          status: attendance.status,
        );
      }
      //untuk ubah status absensi di laporan
      return _ReportItem(
        attendanceId: null,
        studentId: student.id,
        studentName: student.name,
        className: student.className,
        date: date,
        time: '-',
        status: 'Tidak Hadir',
      );
    }).toList();

    items.sort((a, b) => a.studentName.compareTo(b.studentName));
    return items;
  }

  bool _matchesFilters(_ReportItem item) {
    final itemDate = DateTime.tryParse(item.date);
    if (dateFrom != null &&
        (itemDate == null || itemDate.isBefore(_dateOnly(dateFrom!)))) {
      return false;
    }
    if (dateTo != null &&
        (itemDate == null || itemDate.isAfter(_dateOnly(dateTo!)))) {
      return false;
    }
    if (classFilter != null && item.className != classFilter) return false;
    if (statusFilter != null && item.status != statusFilter) return false;
    return true;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> _showFilters() async {
    var selectedClass = classFilter;
    var selectedStatus = statusFilter;
    var selectedFrom = dateFrom;
    var selectedTo = dateTo;
    final classes =
        _students
            .map((student) => student.className)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    const statuses = [
      'Hadir',
      'Terlambat',
      'Sakit',
      'Izin',
      'Dispensasi',
      'Tidak Hadir',
    ];

    final result = await showDialog<_ReportFilter>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final dialogWidth = (screenWidth - 32).clamp(280.0, 440.0);

          Widget dateOption({
            required String label,
            required DateTime? value,
            required VoidCallback onTap,
          }) {
            final text = value == null
                ? '$label: semua'
                : '$label: ${DateFormat('yyyy-MM-dd').format(value)}';
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: const Text('Filter laporan'),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: selectedClass,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kelas',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua kelas'),
                        ),
                        ...classes.map(
                          (value) => DropdownMenuItem<String?>(
                            value: value,
                            child: Text(
                              value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => selectedClass = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua status'),
                        ),
                        ...statuses.map(
                          (value) => DropdownMenuItem<String?>(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => selectedStatus = value),
                    ),
                    const SizedBox(height: 4),
                    dateOption(
                      label: 'Tanggal mulai',
                      value: selectedFrom,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedFrom ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedFrom = picked);
                        }
                      },
                    ),
                    dateOption(
                      label: 'Tanggal akhir',
                      value: selectedTo,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedTo ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTo = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, const _ReportFilter()),
                child: const Text('Reset'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _ReportFilter(
                    className: selectedClass,
                    status: selectedStatus,
                    from: selectedFrom,
                    to: selectedTo,
                  ),
                ),
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      classFilter = result.className;
      statusFilter = result.status;
      dateFrom = result.from;
      dateTo = result.to;
      dateFilter =
          dateFrom != null &&
              dateTo != null &&
              _dateOnly(dateFrom!) == _dateOnly(dateTo!)
          ? DateFormat('yyyy-MM-dd').format(dateFrom!)
          : null;
    });
    await _loadAttendance();
  }

  Future<void> _showEditStatusDialog(_ReportItem item) async {
    final choices = [
      'Hadir',
      'Terlambat',
      'Sakit',
      'Izin',
      'Dispensasi',
      'Tidak Hadir',
    ];
    var selected = item.status;

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Widget buildChoice(String choice) {
            final isSelected = selected == choice;
            final colorScheme = Theme.of(context).colorScheme;

            return Material(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  dialogSetState(() {
                    selected = choice;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          choice,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Ubah status absensi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: choices
                    .map(
                      (choice) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: buildChoice(choice),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(selected),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || result == item.status) return;

    // Apply change: update existing attendance or insert new record
    if (item.attendanceId != null) {
      final updated = Attendance(
        id: item.attendanceId,
        studentId: item.studentId!,
        studentName: item.studentName,
        date: item.date,
        time: item.time,
        status: result,
      );
      await DatabaseService.instance.updateAttendance(updated);
    } else {
      if (item.studentId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal: student id tidak tersedia.')),
        );
        return;
      }

      final newAttendance = Attendance(
        studentId: item.studentId!,
        studentName: item.studentName,
        date: item.date,
        time: '-',
        status: result,
      );
      await DatabaseService.instance.insertAttendance(newAttendance);
    }

    if (!mounted) return;
    await _loadAttendance();
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFilter != null
          ? DateTime.parse(dateFilter!)
          : DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateFilter = DateFormat('yyyy-MM-dd').format(picked);
      });
      _loadAttendance();
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _exportReport() async {
    if (_reportItems.isEmpty) {
      _showMessage('Tidak ada data laporan untuk diekspor.');
      return;
    }

    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(
      ['No', 'Nama Siswa', 'Tanggal', 'Jam', 'Status'].map(_csvCell).join(','),
    );
    for (var index = 0; index < _reportItems.length; index++) {
      final item = _reportItems[index];
      buffer.writeln(
        [
          '${index + 1}',
          item.studentName,
          item.date,
          item.time,
          item.status,
        ].map(_csvCell).join(','),
      );
    }

    final suffix = dateFilter ?? 'semua';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      name: 'rekap_absensi_$suffix.csv',
      mimeType: 'text/csv',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: ['rekap_absensi_$suffix.csv'],
          title: 'Ekspor Rekap Absensi',
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal mengekspor laporan: $error');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = (AuthService.instance.currentRole ?? '')
        .toLowerCase()
        .trim();
    final canEditAttendance = currentRole.contains('admin');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Absensi'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor CSV untuk Excel',
            onPressed: _isLoading || _reportItems.isEmpty
                ? null
                : _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter laporan',
            onPressed: _isLoading ? null : _showFilters,
          ),
          if (dateFilter == null)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showDatePicker,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Chip(
                  label: Text(dateFilter!),
                  onDeleted: () {
                    setState(() {
                      dateFilter = null;
                    });
                    _loadAttendance();
                  },
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportItems.isEmpty
          ? const Center(child: Text('Tidak ada data'))
          : ListView.builder(
              itemCount: _reportItems.length,
              itemBuilder: (context, index) {
                final item = _reportItems[index];
                return _ReportItem.toWidget(
                  context: context,
                  item: item,
                  onTap: canEditAttendance
                      ? () => _showEditStatusDialog(item)
                      : null,
                );
              },
            ),
    );
  }
}

class _ReportItem {
  final int? attendanceId;
  final int? studentId;
  final String studentName;
  final String className;
  final String date;
  final String time;
  final String status;

  _ReportItem({
    required this.attendanceId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.date,
    required this.time,
    required this.status,
  });

  static Widget toWidget({
    required BuildContext context,
    required _ReportItem item,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(item.studentName),
      subtitle: Text('Tanggal: ${item.date}\nJam: ${item.time}'),
      trailing: Text(
        item.status,
        style: TextStyle(
          color: _getStatusColor(item.status),
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    );
  }

  static Color _getStatusColor(String status) {
    //Untuk Pewarnaan status absensi di laporan
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Terlambat':
        return Colors.orange;
      case 'Sakit':
      case 'Izin':
        return Colors.blue;
      case 'Dispensasi':
        return Colors.teal;
      case 'Tidak Hadir':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _ReportFilter {
  final String? className;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  const _ReportFilter({this.className, this.status, this.from, this.to});
}
