import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite/sqflite.dart';

import '../models/student.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nisController = TextEditingController();
  final _classController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  bool _isSaving = false;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    if (student != null) {
      _nameController.text = student.name;
      _nisController.text = student.nis;
      _classController.text = student.className;
      _parentNameController.text = student.parentName;
      _parentPhoneController.text = student.parentPhone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nisController.dispose();
    _classController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isAdmin = (AuthService.instance.currentRole ?? '')
        .toLowerCase()
        .contains('admin');
    if (!isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hanya administrator yang dapat mengubah atau menambah data siswa.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final nis = _nisController.text.trim();
    final className = _classController.text
        .trim(); //Menampilkan sebagai QR menggunakan QrImageView, dan menyimpan NIS sebagai QR Code di database.
    final parentName = _parentNameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();

    try {
      final student = Student(
        id: widget.student?.id,
        name: name,
        nis: nis,
        className: className,
        qrCode: nis,
        parentName: parentName,
        parentPhone: parentPhone,
      );

      if (_isEdit) {
        await DatabaseService.instance.updateStudent(student);
      } else {
        await DatabaseService.instance.insertStudent(student);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on DatabaseException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIS sudah terdaftar. Gunakan NIS yang berbeda.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan siswa: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = (AuthService.instance.currentRole ?? '')
        .toLowerCase()
        .contains('admin');
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Siswa' : 'Tambah Siswa')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Siswa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nisController,
                  decoration: const InputDecoration(
                    labelText: 'NIS',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'NIS wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (_nisController.text.isNotEmpty)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          //Menampilkan QR Code siswa berdasarkan NIS yang diinputkan.
                          children: [
                            const Text(
                              'Preview QR Code:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            QrImageView(
                              data: _nisController.text.trim(),
                              version: QrVersions.auto,
                              size: 150,
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'NIS: ${_nisController.text.trim()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                TextFormField(
                  controller: _classController,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kelas wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parentNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Orang Tua/Wali (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parentPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp Orang Tua/Wali (opsional)',
                    hintText: 'Contoh: 628123456789',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSaving || !isAdmin) ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
