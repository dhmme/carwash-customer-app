import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pages/auth_page.dart';
import 'pages/customer_home_page.dart';
import 'session.dart';

const String baseUrl = 'https://carwash-backend-2yz2.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  runApp(const CustomerApp());
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});
  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  Future<void> _logout() async {
    try { await http.post(Uri.parse('$baseUrl/api/auth/logout/'), headers: Session.authHeaders); } catch (_) {}
    await Session.clear();
    setState(() {});
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Car Wash', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1677ff), surface: const Color(0xfff6f8fc)),
      scaffoldBackgroundColor: const Color(0xfff6f8fc), useMaterial3: true,
      cardTheme: const CardThemeData(elevation: 0),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    ),
    home: Session.token == null
      ? AuthPage(baseUrl: baseUrl, onAuthenticated: () => setState(() {}))
      : CustomerHomePage(baseUrl: baseUrl, onLogout: _logout),
  );
}
