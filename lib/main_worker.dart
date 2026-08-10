import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'pages/auth_page.dart';
import 'pages/worker_bookings_page.dart';
import 'session.dart';

const String baseUrl = 'https://carwash-backend-2yz2.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  runApp(const WorkerApp());
}

class WorkerApp extends StatefulWidget {
  const WorkerApp({super.key});

  @override
  State<WorkerApp> createState() => _WorkerAppState();
}

class _WorkerAppState extends State<WorkerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Session.token == null
          ? AuthPage(
              baseUrl: baseUrl,
              allowRegister: false,
              requireStaff: true,
              onAuthenticated: () => setState(() {}),
            )
          : WorkerBookingsPage(
              onLogout: () async {
                try {
                  await http.post(
                    Uri.parse('$baseUrl/api/auth/logout/'),
                    headers: Session.authHeaders,
                  );
                } catch (_) {}
                await Session.clear();
                setState(() {});
              },
            ),
    );
  }
}
