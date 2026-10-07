import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;
  late final String _resetUid;
  late final String _resetToken;
  bool get _resetMode => _resetUid.isNotEmpty && _resetToken.isNotEmpty;
  static const supportWhatsApp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '966539853212',
  );

  Future<void> _openSupport() async {
    if (supportWhatsApp.isEmpty) return;
    await launchUrl(
      Uri.parse(
        'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent('مرحبًا، أحتاج مساعدة في تطبيق Code Care')}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void initState() {
    super.initState();
    _resetUid = Uri.base.queryParameters['reset_uid'] ?? '';
    _resetToken = Uri.base.queryParameters['reset_token'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_resetMode) {
      await _confirmReset();
      return;
    }
    final endpoint = _register ? 'register' : 'login';
    final body = <String, dynamic>{
      'username': _phoneController.text.trim(),
      'password': _passwordController.text,
      if (_register) 'name': _nameController.text.trim(),
      if (_register) 'email': _emailController.text.trim(),
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
        await Session.saveTokens(
          data['access'] as String,
          data['refresh'] as String,
        );
        widget.onAuthenticated();
      } else {
        setState(() {
          final firstError = data.values.isNotEmpty
              ? data.values.first.toString()
              : null;
          _error =
              data['detail']?.toString() ?? firstError ?? 'تعذر إكمال العملية.';
        });
      }
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestReset() async {
    final email = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نسيت كلمة المرور'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني المسجل',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, email.text.trim()),
            child: const Text('إرسال الرابط'),
          ),
        ],
      ),
    );
    email.dispose();
    if (submitted == null || submitted.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/auth/password-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': submitted}),
      );
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['detail']?.toString() ?? 'تم إرسال الطلب.'),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال رابط إعادة التعيين.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _loading = false;
        _error = 'كلمتا المرور غير متطابقتين.';
      });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/auth/password-reset/confirm/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': _resetUid,
          'token': _resetToken,
          'password': _passwordController.text,
        }),
      );
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور. سجل الدخول الآن.'),
          ),
        );
        windowLocationWithoutReset();
      } else {
        setState(
          () =>
              _error = data['detail']?.toString() ?? 'تعذر تغيير كلمة المرور.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تغيير كلمة المرور.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void windowLocationWithoutReset() {
    launchUrl(Uri.parse(Uri.base.origin), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.navy,
              AppColors.ceruleanDark,
              AppColors.cerulean,
            ],
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
                      const Icon(
                        Icons.local_car_wash,
                        size: 58,
                        color: AppColors.cerulean,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _resetMode
                            ? 'إنشاء كلمة مرور جديدة'
                            : (_register ? 'إنشاء حساب' : 'تسجيل الدخول'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      if (_register && !_resetMode)
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'أدخل الاسم'
                              : null,
                        ),
                      if (_register && !_resetMode) const SizedBox(height: 12),
                      if (_register && !_resetMode)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                              : null,
                        ),
                      if (_register && !_resetMode) const SizedBox(height: 12),
                      if (!_resetMode)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الجوال',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 10
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
                      if (_resetMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.length < 8
                              ? 'أعد كتابة كلمة المرور'
                              : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _resetMode
                                      ? 'حفظ كلمة المرور'
                                      : (_register ? 'إنشاء الحساب' : 'دخول'),
                                ),
                        ),
                      ),
                      if (widget.allowRegister && !_resetMode)
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                          child: Text(
                            _register
                                ? 'لديك حساب؟ سجل الدخول'
                                : 'ليس لديك حساب؟ أنشئ حساباً',
                          ),
                        ),
                      if (widget.allowRegister && !_register && !_resetMode)
                        TextButton(
                          onPressed: _loading ? null : _requestReset,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      if (widget.allowRegister && supportWhatsApp.isNotEmpty)
                        TextButton.icon(
                          onPressed: _openSupport,
                          icon: const Icon(Icons.support_agent),
                          label: const Text(
                            'تواصل معنا عبر واتساب للدعم الفني',
                          ),
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
