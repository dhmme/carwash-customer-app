import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carwash_app/app_theme.dart';
import 'package:carwash_app/pages/auth_page.dart';

void main() {
  testWidgets('customer login screen renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AuthPage(
          baseUrl: 'https://example.test',
          onAuthenticated: () {},
        ),
      ),
    );

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
  });
}
