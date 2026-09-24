import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../session.dart';
import '../worker_localization.dart';

class WorkerAuthPage extends StatefulWidget {
  const WorkerAuthPage({super.key, required this.baseUrl, required this.localizations, required this.onLanguageChanged, required this.onAuthenticated});
  final String baseUrl;
  final WorkerLocalizations localizations;
  final ValueChanged<WorkerLanguage> onLanguageChanged;
  final VoidCallback onAuthenticated;
  @override
  State<WorkerAuthPage> createState() => _WorkerAuthPageState();
}

class _WorkerAuthPageState extends State<WorkerAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse(widget.baseUrl + '/api/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _phoneController.text.trim(), 'password': _passwordController.text}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (data['is_staff'] != true) {
          setState(() => _error = widget.localizations.unauthorizedWorker);
          return;
        }
        final access = data['access']?.toString();
        final refresh = data['refresh']?.toString();
        if (access == null || refresh == null) {
          setState(() => _error = widget.localizations.operationFailed);
          return;
        }
        await Session.saveTokens(access, refresh);
        widget.onAuthenticated();
      } else {
        setState(() => _error = widget.localizations.operationFailed);
      }
    } catch (_) {
      setState(() => _error = widget.localizations.serverUnavailable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.localizations;
    return Directionality(
      textDirection: strings.textDirection,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.ceruleanDark, AppColors.cerulean],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(children: [
            PositionedDirectional(
              top: 16, end: 16,
              child: SafeArea(child: _LanguageMenu(localizations: strings, onChanged: widget.onLanguageChanged)),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_car_wash, size: 58, color: AppColors.cerulean),
                          const SizedBox(height: 12),
                          Text(strings.appName, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 6),
                          Text(strings.login),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(labelText: strings.phone, border: const OutlineInputBorder()),
                            validator: (value) => value == null || value.trim().length < 10 ? strings.enterValidPhone : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(labelText: strings.password, border: const OutlineInputBorder()),
                            validator: (value) => value == null || value.length < 8 ? strings.passwordLength : null,
                            onFieldSubmitted: (_) { if (!_loading) _submit(); },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(strings.login),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.localizations, required this.onChanged});
  final WorkerLocalizations localizations;
  final ValueChanged<WorkerLanguage> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<WorkerLanguage>(
    tooltip: localizations.changeLanguage,
    initialValue: localizations.language,
    onSelected: onChanged,
    itemBuilder: (_) => WorkerLanguage.values.map((language) => PopupMenuItem(
      value: language,
      child: Text(localizations.languageLabel(language)),
    )).toList(),
    child: Chip(avatar: const Icon(Icons.language, size: 18), label: Text(localizations.languageName)),
  );
}
