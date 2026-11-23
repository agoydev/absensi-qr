import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _storageKey = 'auth_accounts';

  final Map<String, Map<String, String>> _accounts = {
    'admin': {'password': 'admin123', 'role': 'Admin'},
    'guru': {'password': 'guru123', 'role': 'Guru'},
  };

  String? _currentRole;
  String? _currentUsername;

  String? get currentRole => _currentRole;
  String? get currentUsername => _currentUsername;

  Future<String?> cloudLogin(String username, String password) async {
    final payload = await ApiService.instance.login(
      username: username,
      password: password,
    );
    final user = payload['user'];
    if (user is! Map) {
      throw StateError('Respons login cloud tidak memiliki data pengguna.');
    }
    _currentUsername = user['username']?.toString();
    final role = user['role']?.toString();
    _currentRole = role == 'teacher' ? 'Guru' : 'Admin';
    return _currentRole;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null || stored.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(stored);
    if (decoded is! Map) {
      return;
    }

    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is Map) {
        final password = value['password']?.toString();
        final role = value['role']?.toString();
        if (password != null &&
            password.isNotEmpty &&
            role != null &&
            role.isNotEmpty) {
          _accounts[entry.key.toString().toLowerCase()] = {
            'password': password,
            'role': role,
          };
        }
      }
    }
  }

  Future<bool> registerAccount({
    required String username,
    required String password,
    required String role,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final normalizedRole = role.trim();

    if (normalizedUsername.isEmpty ||
        normalizedPassword.isEmpty ||
        normalizedRole.isEmpty) {
      return false;
    }

    if (_accounts.containsKey(normalizedUsername)) {
      return false;
    }

    _accounts[normalizedUsername] = {
      'password': normalizedPassword,
      'role': normalizedRole,
    };
    await _saveAccounts();
    return true;
  }

  Future<void> registerCloudTeacher({
    required String username,
    required String password,
  }) {
    return ApiService.instance.registerTeacher(
      username: username,
      password: password,
    );
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_accounts));
  }

  String? login(String username, String password) {
    final normalizedUsername = username.trim().toLowerCase();
    final normalizedPassword = password.trim();

    final account = _accounts[normalizedUsername];
    if (account == null || account['password'] != normalizedPassword) {
      return null;
    }

    _currentRole = account['role'];
    _currentUsername = normalizedUsername;
    return _currentRole;
  }
}
