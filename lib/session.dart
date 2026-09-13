import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Session {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _baseUrl = 'https://carwash-backend-2yz2.onrender.com';
  static const _storage = FlutterSecureStorage();
  static String? accessToken;
  static String? refreshToken;
  static Future<void> Function()? onUnauthorized;

  static Future<void> load() async {
    accessToken = await _storage.read(key: _accessKey);
    refreshToken = await _storage.read(key: _refreshKey);
  }

  static Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await Future.wait([
      _storage.write(key: _accessKey, value: access),
      _storage.write(key: _refreshKey, value: refresh),
    ]);
  }

  static Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }

  static Future<void> handleUnauthorized() async {
    if (await refresh()) return;
    await clear();
    await onUnauthorized?.call();
  }

  static Future<bool> refresh() async {
    final currentRefresh = refreshToken;
    if (currentRefresh == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': currentRefresh}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access']?.toString();
      if (access == null) return false;
      await saveTokens(access, data['refresh']?.toString() ?? currentRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get isAuthenticated => accessToken != null;

  static String get logoutBody => jsonEncode({'refresh': refreshToken});

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };
}
