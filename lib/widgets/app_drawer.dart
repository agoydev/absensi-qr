import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String role;
  final Color accentColor;
  final Color accentColorSoft;
  final VoidCallback onDataSiswa;
  final VoidCallback onScanAbsensi;
  final VoidCallback onLaporan;
  final VoidCallback onChat;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.role,
    required this.accentColor,
    required this.accentColorSoft,
    required this.onDataSiswa,
    required this.onScanAbsensi,
    required this.onLaporan,
    required this.onChat,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColorSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: const Text('Sistem Absensi QR'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: accentColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.groups_rounded, color: accentColor),
                  title: const Text('Data Siswa'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDataSiswa();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: accentColor,
                  ),
                  title: const Text('Scan Absensi'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onScanAbsensi();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.assignment_rounded, color: accentColor),
                  title: const Text('Laporan Absensi'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onLaporan();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.chat_rounded, color: accentColor),
                  title: const Text('Chat Bot'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onChat();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () {
              Navigator.of(context).pop();
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}
