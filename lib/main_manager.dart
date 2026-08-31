import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'pages/auth_page.dart';
import 'pages/manager_page.dart';
import 'session.dart';

const baseUrl = 'https://carwash-backend-2yz2.onrender.com';

class ManagerApp extends StatefulWidget {
  const ManagerApp({super.key});
  @override State<ManagerApp> createState() => _ManagerAppState();
}

class _ManagerAppState extends State<ManagerApp> {
  @override void initState() { super.initState(); Session.onUnauthorized = () async { if (mounted) setState(() {}); }; }
  @override void dispose() { Session.onUnauthorized = null; super.dispose(); }
  Future<void> logout() async {
    try { await http.post(Uri.parse('$baseUrl/api/auth/logout/'), headers: Session.authHeaders); } catch (_) {}
    await Session.clear(); if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'إدارة المغسلة', debugShowCheckedModeBanner: false, theme: buildAppTheme(),
    home: Session.token == null
      ? AuthPage(baseUrl: baseUrl, allowRegister: false, requireManager: true, onAuthenticated: () => setState(() {}))
      : ManagerPage(onLogout: logout),
  );
}
