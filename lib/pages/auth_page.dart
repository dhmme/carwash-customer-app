import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../session.dart';
import '../app_theme.dart';

class AuthPage extends StatefulWidget {
  final String baseUrl;
  final VoidCallback onAuthenticated;
  final bool allowRegister;
  final bool requireStaff;
  final bool requireManager;

  const AuthPage({
    super.key,
    required this.baseUrl,
    required this.onAuthenticated,
    this.allowRegister = true,
    this.requireStaff = false,
    this.requireManager = false,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final endpoint = _register ? 'register' : 'login';
    final body = <String, dynamic>{
      'username': _phoneController.text.trim(),
      'password': _passwordController.text,
      if (_register) 'name': _nameController.text.trim(),
      if (_register) 'email': '',
    };

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/auth/$endpoint/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (widget.requireStaff && data['is_staff'] != true) {
          setState(() => _error = 'هذا الحساب غير مصرح له بدخول العمال.');
          return;
        }
        if (widget.requireManager && data['is_superuser'] != true) {
          setState(() => _error = 'هذا الحساب غير مصرح له بدخول الإدارة.');
          return;
        }
        await Session.saveToken(data['token'] as String);
        widget.onAuthenticated();
      } else {
        setState(() {
          final firstError = data.values.isNotEmpty
              ? data.values.first.toString()
              : null;
          _error = data['detail']?.toString() ??
              firstError ??
              'تعذر إكمال العملية.';
        });
      }
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.ceruleanDark, AppColors.cerulean],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_car_wash,
                          size: 58, color: AppColors.cerulean),
                      const SizedBox(height: 12),
                      Text(
                        _register ? 'إنشاء حساب' : 'تسجيل الدخول',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      if (_register)
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'أدخل الاسم'
                              : null,
                        ),
                      if (_register) const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الجوال',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().length < 10
                            ? 'أدخل رقم جوال صحيح'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'كلمة المرور يجب ألا تقل عن 8 أحرف'
                            : null,
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
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_register ? 'إنشاء الحساب' : 'دخول'),
                        ),
                      ),
                      if (widget.allowRegister) TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                        child: Text(_register
                            ? 'لديك حساب؟ سجل الدخول'
                            : 'ليس لديك حساب؟ أنشئ حساباً'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
