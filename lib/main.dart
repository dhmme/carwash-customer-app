import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pages/auth_page.dart';
import 'pages/customer_home_page.dart';
import 'session.dart';
import 'app_theme.dart';
import 'main_worker.dart' as worker;

const String baseUrl = 'https://carwash-backend-2yz2.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  if (Uri.base.path.startsWith('/worker')) {
    runApp(const worker.WorkerApp());
  } else {
    runApp(const CustomerApp());
  }
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});
  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  @override
  void initState() {
    super.initState();
    Session.onUnauthorized = () async {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    Session.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _logout() async {
    try { await http.post(Uri.parse('$baseUrl/api/auth/logout/'), headers: Session.authHeaders); } catch (_) {}
    await Session.clear();
    setState(() {});
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Car Wash', debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Session.token == null
      ? AuthPage(baseUrl: baseUrl, onAuthenticated: () => setState(() {}))
      : CustomerHomePage(baseUrl: baseUrl, onLogout: _logout),
  );
}
