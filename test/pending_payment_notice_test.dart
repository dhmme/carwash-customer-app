import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:carwash_app/widgets/pending_payment_notice.dart';

void main() {
  testWidgets('reminds about pending payment then removes hold on server expiry', (tester) async {
    var expired = false;
    var changed = 0;
    final client = MockClient((request) async => http.Response(jsonEncode([
      {'id': 7, 'status': expired ? 'canceled' : 'pending',
        'payment_status': expired ? 'expired' : 'pending',
        'payment_expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'payment_checkout_url': 'https://example.com/pay', 'date': '2026-12-01', 'time_slot': '4pm'},
      {'id': 8, 'status': 'accepted', 'payment_status': 'paid'},
    ]), 200));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PendingPaymentNotice(
        baseUrl: 'https://example.com', onChanged: () => changed++,
      ))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('🔔 حجزك #7 بانتظار الدفع'), findsOneWidget);
      expect(find.text('إكمال الدفع'), findsOneWidget);
      expect(find.text('إلغاء الحجز'), findsOneWidget);
      expect(find.textContaining('#8'), findsNothing);
      expired = true;
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('🔔 حجزك #7 بانتظار الدفع'), findsNothing);
      expect(changed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    client.close();
  });
}
