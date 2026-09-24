import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'pages/worker_auth_page.dart';
import 'pages/worker_bookings_page.dart';
import 'session.dart';
import 'app_theme.dart';
import 'app_config.dart';
import 'worker_localization.dart';

const String baseUrl = AppConfig.apiBaseUrl;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  final language = await WorkerLocalizations.loadLanguage();
  runApp(WorkerApp(initialLanguage: language));
}

class WorkerApp extends StatefulWidget {
  const WorkerApp({super.key, required this.initialLanguage});

  final WorkerLanguage initialLanguage;

  @override
  State<WorkerApp> createState() => _WorkerAppState();
}

class _WorkerAppState extends State<WorkerApp> {
  late WorkerLanguage _language;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    Session.onUnauthorized = () async {
      if (mounted) setState(() {});
    };
  }

  Future<void> _changeLanguage(WorkerLanguage language) async {
    if (_language == language) return;
    setState(() => _language = language);
    await WorkerLocalizations.saveLanguage(language);
  }

  @override
  void dispose() {
    Session.onUnauthorized = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = WorkerLocalizations(_language);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: strings.locale,
      builder: (context, child) =>
          Directionality(textDirection: strings.textDirection, child: child!),
      home: !Session.isAuthenticated
          ? WorkerAuthPage(
              baseUrl: baseUrl,
              localizations: strings,
              onLanguageChanged: _changeLanguage,
              onAuthenticated: () => setState(() {}),
            )
          : WorkerBookingsPage(
              localizations: strings,
              onLanguageChanged: _changeLanguage,
              onLogout: () async {
                try {
                  await http.post(
                    Uri.parse('$baseUrl/api/auth/logout/'),
                    headers: Session.authHeaders,
                    body: Session.logoutBody,
                  );
                } catch (_) {}
                await Session.clear();
                setState(() {});
              },
            ),
    );
  }
}
