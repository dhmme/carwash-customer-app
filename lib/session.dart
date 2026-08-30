import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _tokenKey = 'auth_token';
  static String? token;
  static Future<void> Function()? onUnauthorized;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    token = preferences.getString(_tokenKey);
  }

  static Future<void> saveToken(String value) async {
    token = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, value);
  }

  static Future<void> clear() async {
    token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  static Future<void> handleUnauthorized() async {
    await clear();
    await onUnauthorized?.call();
  }

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };
}
