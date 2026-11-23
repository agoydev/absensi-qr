import 'package:flutter/material.dart';

import '../services/database_service.dart';

class UserManagementScreen extends StatefulWidget {
  static const routeName = '/users';

  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<_ManagedUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _reloadUsers();
  }

  void _reloadUsers() {
    _usersFuture = DatabaseService.instance.getUsers().then(
      (users) => users.map(_ManagedUser.fromMap).toList(),
    );
  }

  Future<void> _showCreateUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'teacher';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final dialogWidth = (screenWidth - 32).clamp(280.0, 440.0);

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          actionsOverflowButtonSpacing: 8,
          title: const Text('Tambah Akun'),
          content: SizedBox(
            width: dialogWidth,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama lengkap',
                        isDense: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        isDense: true,
                      ),
                      validator: _required,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'Minimal 8 karakter',
                        isDense: true,
                      ),
                      obscureText: true,
                      validator: (value) => value != null && value.length >= 8
                          ? null
                          : 'Minimal 8 karakter',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('Guru'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: (value) => role = value ?? role,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await DatabaseService.instance.createUser(
                    name: nameController.text.trim(),
                    username: usernameController.text.trim(),
                    password: passwordController.text,
                    role: role,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();

    if (created == true && mounted) {
      _reloadUsers();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Akun berhasil dibuat.')));
    }
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Wajib diisi' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun'),
        actions: [
          IconButton(
            onPressed: _showCreateUserDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Tambah akun',
          ),
        ],
      ),
      body: FutureBuilder<List<_ManagedUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat akun.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final users = snapshot.data ?? const <_ManagedUser>[];
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada akun.\nTekan tombol tambah untuk membuat akun.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reloadUsers();
              setState(() {});
              await _usersFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                final isAdmin = user.role == 'admin';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.school_outlined,
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Text('@${user.username}'),
                    trailing: Chip(
                      label: Text(isAdmin ? 'Admin' : 'Guru'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ManagedUser {
  final String name;
  final String username;
  final String role;

  const _ManagedUser({
    required this.name,
    required this.username,
    required this.role,
  });

  factory _ManagedUser.fromMap(Map<String, dynamic> map) {
    return _ManagedUser(
      name: map['name']?.toString() ?? '-',
      username: map['username']?.toString() ?? '-',
      role: map['role']?.toString().toLowerCase() ?? 'teacher',
    );
  }
}
