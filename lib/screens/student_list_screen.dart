import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/student.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/qr_card_pdf_service.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatefulWidget {
  static const routeName = '/students';

  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  bool _isLoading = true;
  List<Student> _students = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService.instance.getStudents();
      if (!mounted) return;
      setState(() {
        _students = data;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({Student? student}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormScreen(student: student),
      ),
    );

    if (changed == true) {
      _loadStudents();
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Data'),
          content: Text('Yakin ingin menghapus ${student.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || student.id == null) {
      return;
    }

    await DatabaseService.instance.deleteStudent(student.id!);
    _loadStudents();
  }

  void _showQrDialog(Student student) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'QR ${student.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: student.qrCode,
                    version: QrVersions.auto,
                    size: 180,
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NIS: ${student.qrCode}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  student.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareQrCards({Student? student}) async {
    final students = student == null ? _students : [student];
    if (students.isEmpty) {
      _showMessage('Belum ada data siswa untuk dicetak.');
      return;
    }

    try {
      final bytes = await QrCardPdfService.generate(students);
      final fileName = student == null
          ? 'kartu_qr_siswa.pdf'
          : 'kartu_qr_${student.nis}.pdf';
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        name: fileName,
        mimeType: 'application/pdf',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [fileName],
          title: 'Kartu QR Siswa',
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal membuat kartu QR: $error');
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
    final isAdmin = (AuthService.instance.currentRole ?? '')
        .toLowerCase()
        .contains('admin');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa'),
        actions: [
          if (_students.isNotEmpty)
            IconButton(
              tooltip: 'Cetak semua kartu QR',
              onPressed: () => _shareQrCards(),
              icon: const Icon(Icons.picture_as_pdf),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagal memuat data siswa:\n$_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadStudents,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : _students.isEmpty
          ? const Center(child: Text('Belum ada data siswa.'))
          : RefreshIndicator(
              onRefresh: _loadStudents,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(student.name),
                      subtitle: Text(
                        'NIS: ${student.nis} | Kelas: ${student.className}',
                      ),
                      onTap: () => _showQrDialog(student),
                      trailing: isAdmin
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(student: student);
                                }
                                if (value == 'delete') {
                                  _deleteStudent(student);
                                }
                                if (value == 'print') {
                                  _shareQrCards(student: student);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'print',
                                  child: Text('Cetak kartu QR'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Siswa'),
            )
          : null,
    );
  }
}
