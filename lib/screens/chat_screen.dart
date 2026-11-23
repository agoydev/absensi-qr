import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat';

  final String role;

  const ChatScreen({super.key, required this.role});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  Map<String, Map<String, String>> _cannedByRole = {};

  static const Map<String, Map<String, String>> _defaultCanned = {
    'admin': {
      'Cara tambah user?':
          'Masuk ke menu Admin → Pengguna → Tambah, isi data, simpan.',
      'Bagaimana backup data?':
          'Gunakan fitur Ekspor di Pengaturan → Backup Data.',
      'Setting lokasi?':
          'Di Pengaturan Sistem Anda bisa mengatur radius verifikasi lokasi.',
    },
    'guru': {
      'Cara pakai aplikasi?': 'Buka menu Scan → Pindai QR siswa untuk absensi.',
      'Lihat laporan?':
          'Masuk ke Laporan → pilih tanggal/kelas → lihat ringkasan.',
      'Butuh bantuan?': 'Hubungi admin sekolah atau gunakan menu Bantuan.',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadResponses() async {
    try {
      final s = await rootBundle.loadString('assets/responses.json');
      final Map<String, dynamic> data = json.decode(s);
      final Map<String, Map<String, String>> converted = {};
      data.forEach((k, v) {
        if (v is Map) {
          converted[k] = v.map(
            (key, val) => MapEntry(key.toString(), val.toString()),
          );
        }
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _cannedByRole = converted.isNotEmpty ? converted : _defaultCanned;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cannedByRole = _defaultCanned;
      });
    }
  }

  String _findResponse(String text, String roleKey) {
    final normalized = text.toLowerCase().trim();
    final responses = _cannedByRole[roleKey] ?? _defaultCanned[roleKey] ?? {};

    for (final entry in responses.entries) {
      final keywords = entry.key
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.length >= 4)
          .toList();
      final matchCount = keywords
          .where((keyword) => normalized.contains(keyword))
          .length;
      if (matchCount >= 2 || normalized == entry.key.toLowerCase()) {
        return entry.value;
      }
    }

    return 'Maaf, saya belum memiliki jawaban untuk pertanyaan itu. '
        'Coba tanyakan tentang absensi QR, laporan, data siswa, '
        'atau minta bantuan admin.';
  }

  void _sendUserMessage(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    _messageController.clear();
    setState(() {
      _messages.add({'who': 'user', 'text': normalizedText});
    });

    final roleKey = widget.role.toLowerCase().contains('admin')
        ? 'admin'
        : 'guru';
    final resp = _findResponse(normalizedText, roleKey);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add({'who': 'bot', 'text': resp});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleKey = widget.role.toLowerCase().contains('admin')
        ? 'admin'
        : 'guru';
    final canned = _cannedByRole.isNotEmpty
        ? (_cannedByRole[roleKey] ?? {})
        : (_defaultCanned[roleKey] ?? {});
    final roleLabel = roleKey == 'admin' ? 'Administrator' : 'Guru';

    return Scaffold(
      appBar: AppBar(title: Text('Chat Bot — $roleLabel')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m['who'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary.withAlpha(200)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m['text'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saran cepat:'),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    children: canned.keys.map((k) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () => _sendUserMessage(k),
                          child: Text(k),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendUserMessage,
                        decoration: const InputDecoration(
                          hintText: 'Tulis pertanyaan...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Kirim',
                      onPressed: () =>
                          _sendUserMessage(_messageController.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
