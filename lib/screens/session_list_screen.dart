import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import '../services/database_service.dart';
import 'scan_screen.dart';

class SessionListScreen extends StatefulWidget {
  static const routeName = '/sessions';

  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  late Future<List<AttendanceSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sessionsFuture = DatabaseService.instance.getSessions(
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  Future<void> _openSession(AttendanceSession session) async {
    if (session.status == 'cancelled' || session.status == 'completed') {
      _showError('Sesi ini sudah ditutup dan tidak dapat dibuka kembali.');
      return;
    }

    if (!session.isOngoing) {
      try {
        await DatabaseService.instance.updateSessionStatus(
          sessionId: session.id,
          status: 'ongoing',
        );
        if (!mounted) return;
        _reload();
        setState(() {});
      } catch (error) {
        _showError(error.toString());
        return;
      }
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(session: session)),
    );
    if (mounted) {
      _reload();
      setState(() {});
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesi Hari Ini')),
      body: FutureBuilder<List<AttendanceSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat sesi: ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? const [];
          if (sessions.isEmpty) {
            return const Center(
              child: Text('Belum ada sesi pembelajaran untuk hari ini.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              setState(() {});
              await _sessionsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  child: ListTile(
                    title: Text(session.subjectName),
                    subtitle: Text(
                      '${session.className} • Pertemuan ${session.meetingNumber}\n'
                      '${session.startAt} - ${session.endAt}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(label: Text(session.status)),
                    onTap: () => _openSession(session),
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
