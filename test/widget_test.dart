import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_qr/main.dart';
import 'package:absensi_qr/screens/chat_screen.dart';
import 'package:absensi_qr/screens/dashboard_screen.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AbsensiQrApp());
    expect(find.text('Absensi Siswa QR'), findsOneWidget);
  });

  testWidgets('Chat bot can be opened and answers quick questions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardScreen(role: 'Guru'),
        routes: {
          ChatScreen.routeName: (context) =>
              const ChatScreen(role: 'Guru'),
        },
      ),
    );

    await tester.tap(find.text('Chat Bot'));
    await tester.pumpAndSettle();

    expect(find.text('Chat Bot — Guru'), findsOneWidget);
    await tester.tap(find.text('Cara pakai aplikasi?'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Buka menu Scan'), findsOneWidget);
  });
}
