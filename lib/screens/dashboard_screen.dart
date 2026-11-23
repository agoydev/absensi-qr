import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'report_screen.dart';
import 'student_list_screen.dart';
import 'session_list_screen.dart';
import 'schedule_screen.dart';
import 'master_data_screen.dart';
import 'user_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const routeName = '/dashboard';

  static const Color _dashboardPrimary = Color(0xFF6C739F);
  static const Color _dashboardSecondary = Color(0xFF8790BC);
  static const Color _dashboardBackgroundTop = Color(0xFFFDFDFF);
  static const Color _dashboardBackgroundBottom = Color(0xFFF1F3FF);

  final String role;

  const DashboardScreen({super.key, required this.role});

  void _openStudents(BuildContext context) {
    Navigator.pushNamed(context, StudentListScreen.routeName);
  }

  void _openScan(BuildContext context) {
    Navigator.pushNamed(context, SessionListScreen.routeName);
  }

  void _openReport(BuildContext context) {
    Navigator.pushNamed(context, ReportScreen.routeName);
  }

  void _openSchedules(BuildContext context) {
    Navigator.pushNamed(context, ScheduleScreen.routeName);
  }

  void _openMasterData(BuildContext context) {
    Navigator.pushNamed(context, MasterDataScreen.routeName);
  }

  void _openUserManagement(BuildContext context) {
    Navigator.pushNamed(context, UserManagementScreen.routeName);
  }

  void _openChat(BuildContext context) {
    Navigator.pushNamed(context, ChatScreen.routeName, arguments: role);
  }

  void _logout(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      LoginScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase().contains('admin');
    final roleColor = _dashboardPrimary;
    final roleColorSoft = _dashboardSecondary;
    final roleLabel = isAdmin ? 'Administrator' : 'Guru';

    final menuItems = isAdmin
        ? <_DashboardMenuItem>[
            _DashboardMenuItem(
              title: 'Data Siswa',
              icon: Icons.groups_rounded,
              onTap: () => _openStudents(context),
            ),
            _DashboardMenuItem(
              title: 'Scan Absensi',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => _openScan(context),
            ),
            _DashboardMenuItem(
              title: 'Manajemen Akun',
              icon: Icons.manage_accounts,
              onTap: () => _openUserManagement(context),
            ),
            _DashboardMenuItem(
              title: 'Data Master',
              icon: Icons.settings,
              onTap: () => _openMasterData(context),
            ),
            _DashboardMenuItem(
              title: 'Jadwal',
              icon: Icons.calendar_month_rounded,
              onTap: () => _openSchedules(context),
            ),
            _DashboardMenuItem(
              title: 'Chat Bot',
              icon: Icons.chat_rounded,
              onTap: () => _openChat(context),
            ),
            _DashboardMenuItem(
              title: 'Laporan Absensi',
              icon: Icons.assignment_rounded,
              onTap: () => _openReport(context),
            ),
            _DashboardMenuItem(
              title: 'Logout',
              icon: Icons.logout_rounded,
              onTap: () => _logout(context),
            ),
          ]
        : <_DashboardMenuItem>[
            _DashboardMenuItem(
              title: 'Scan Absensi',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => _openScan(context),
            ),
            _DashboardMenuItem(
              title: 'Chat Bot',
              icon: Icons.chat_rounded,
              onTap: () => _openChat(context),
            ),
            _DashboardMenuItem(
              title: 'Laporan Absensi',
              icon: Icons.assignment_rounded,
              onTap: () => _openReport(context),
            ),
            _DashboardMenuItem(
              title: 'Logout',
              icon: Icons.logout_rounded,
              onTap: () => _logout(context),
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: AppDrawer(
        role: role,
        accentColor: roleColor,
        accentColorSoft: roleColorSoft,
        onDataSiswa: () => _openStudents(context),
        onScanAbsensi: () => _openScan(context),
        onLaporan: () => _openReport(context),
        onChat: () => _openChat(context),
        onLogout: () => _logout(context),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_dashboardBackgroundTop, _dashboardBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selamat datang, $role',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Chip(
                    label: Text(
                      roleLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: roleColor,
                    side: BorderSide(color: roleColorSoft.withOpacity(0.35)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Pilih menu untuk mengelola absensi siswa.'),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: menuItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final onPrimary = Colors.white;
                    return GestureDetector(
                      onTap: item.onTap,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [roleColor, roleColorSoft],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withOpacity(0.24),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, size: 44, color: onPrimary),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}
