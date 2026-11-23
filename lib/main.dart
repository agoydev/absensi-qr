import 'package:flutter/material.dart';

import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/student_list_screen.dart';
import 'screens/register_screen.dart';
import 'screens/session_list_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/master_data_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await AuthService.instance.init();
  runApp(const AbsensiQrApp());
}

class AbsensiQrApp extends StatelessWidget {
  const AbsensiQrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Absensi QR Siswa SMK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C739F)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDFDFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        RegisterScreen.routeName: (context) => const RegisterScreen(),
        StudentListScreen.routeName: (context) => const StudentListScreen(),
        ScanScreen.routeName: (context) =>
            const ScanScreen(), //untuk registrasi siswa, menampilkan daftar siswa, dan scan QR Code siswa untuk absensi.
        ReportScreen.routeName: (context) => const ReportScreen(),
        SessionListScreen.routeName: (context) => const SessionListScreen(),
        ScheduleScreen.routeName: (context) => const ScheduleScreen(),
        MasterDataScreen.routeName: (context) => const MasterDataScreen(),
        UserManagementScreen.routeName: (context) =>
            const UserManagementScreen(),
        ChatScreen.routeName: (context) {
          final role = ModalRoute.of(context)?.settings.arguments as String?;
          return ChatScreen(role: role ?? 'Guru');
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == DashboardScreen.routeName) {
          final role = settings.arguments as String? ?? 'Guru';
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(role: role),
          );
        }
        return null;
      },
    );
  }
}
