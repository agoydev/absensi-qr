import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/database_service.dart';

class MasterDataScreen extends StatefulWidget {
  static const routeName = '/master-data';

  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  late Future<_MasterData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _dataFuture =
        Future.wait([
          DatabaseService.instance.getClasses(),
          DatabaseService.instance.getSubjects(),
        ]).then(
          (values) => _MasterData(
            classes: values[0] as List<SchoolClass>,
            subjects: values[1] as List<Subject>,
          ),
        );
  }

  Future<void> _addClass() async {
    final values = await _showFields(
      title: 'Tambah Kelas',
      fields: const [
        _FieldSpec('Nama kelas', 'X RPL 1'),
        _FieldSpec('Tingkat', 'X'),
        _FieldSpec('Jurusan', 'Rekayasa Perangkat Lunak'),
        _FieldSpec('Tahun ajaran', '2026/2027'),
      ],
    );
    if (values == null) return;
    try {
      await DatabaseService.instance.createClass(
        name: values[0],
        gradeLevel: values[1],
        major: values[2],
        schoolYear: values[3],
      );
      await _refresh();
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _addSubject() async {
    final values = await _showFields(
      title: 'Tambah Mata Pelajaran',
      fields: const [
        _FieldSpec('Kode', 'P dasar'),
        _FieldSpec('Nama mata pelajaran', 'Pemrograman Dasar'),
      ],
    );
    if (values == null) return;
    try {
      await DatabaseService.instance.createSubject(
        code: values[0],
        name: values[1],
      );
      await _refresh();
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<List<String>?> _showFields({
    required String title,
    required List<_FieldSpec> fields,
  }) async {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => _FieldsDialog(title: title, fields: fields),
    );
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    _reload();
    setState(() {});
    await _dataFuture;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Master')),
      body: FutureBuilder<_MasterData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              await _refresh();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  title: 'Kelas',
                  icon: Icons.groups,
                  onAdd: _addClass,
                  children: data.classes
                      .map((item) => ListTile(title: Text(item.name)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Mata Pelajaran',
                  icon: Icons.menu_book,
                  onAdd: _addSubject,
                  children: data.subjects
                      .map(
                        (item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.code),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada data.'),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _MasterData {
  final List<SchoolClass> classes;
  final List<Subject> subjects;

  const _MasterData({required this.classes, required this.subjects});
}

class _FieldSpec {
  final String label;
  final String initialValue;

  const _FieldSpec(this.label, this.initialValue);
}

class _FieldsDialog extends StatefulWidget {
  final String title;
  final List<_FieldSpec> fields;

  const _FieldsDialog({required this.title, required this.fields});

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((field) => TextEditingController(text: field.initialValue))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < widget.fields.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers[index],
                    decoration: InputDecoration(
                      labelText: widget.fields[index].label,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Wajib diisi'
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _controllers.map((controller) => controller.text.trim()).toList(),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
