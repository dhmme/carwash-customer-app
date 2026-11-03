import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwash_app/app_theme.dart';
import 'package:carwash_app/pages/manager_packages_page.dart';
import 'package:carwash_app/pages/customer_packages_manager_page.dart';

Map<String, dynamic> plan(int id, {bool archived = false}) => {
  'id': id, 'name': 'باقة مستقلة $id', 'price': '99.00', 'washes_count': 4,
  'validity_days': 60, 'included_service': 1, 'included_service_name': 'غسيل كامل',
  'is_active': !archived, 'is_archived': archived, 'buyers_count': 2,
  'purchase_count': 3, 'customer_count': 2, 'grants_count': 0,
  'active_count': 2, 'pending_count': 1,
};
Map<String, dynamic> member() => {
  'id': 11, 'customer': 5, 'customer_name': 'عميل الباقة الأولى',
  'customer_phone': '0551234567', 'plan': 1, 'plan_name': 'شروط الباقة القديمة',
  'price': '77.00', 'washes_count': 4, 'remaining_washes': 3, 'used_washes': 1,
  'status': 'active', 'effective_status': 'active', 'payment_method': 'cash',
  'purchased_at': '2026-11-01T12:00:00Z', 'expires_at': '2027-01-01T12:00:00Z',
};
Widget app(Widget child) => MaterialApp(theme: buildAppTheme(), home:
  Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)));

void main() {
  testWidgets('each plan opens only its own subscribers, including archived plans', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    Future<dynamic> request(String path, String method, Map<String, dynamic>? body) async {
      calls.add(path);
      if (path == 'packages/') return [plan(1, archived: true), plan(2)];
      if (path == 'packages/1/') return plan(1, archived: true);
      if (path.startsWith('package-purchases/')) {
        expect(Uri.parse(path).queryParameters['plan'], '1');
        return {'count': 1, 'page': 1, 'total_pages': 1, 'results': [member()]};
      }
      throw StateError(path);
    }
    await tester.pumpWidget(app(ManagerPackagesPage(request: request, services: const [],
      customers: const [], onChanged: () async {})));
    await tester.pumpAndSettle();
    final card = find.byWidgetPredicate((w) => w is PackagePlanCard && w.plan['id'] == 1);
    final manage = find.descendant(of: card, matching: find.text('إدارة الباقة والمشتركين'));
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    expect(find.text('عميل الباقة الأولى • اشتراك #11'), findsOneWidget);
    expect(find.textContaining('شروط الباقة القديمة'), findsOneWidget);
    expect(find.text('الغسلات المتبقية: 3'), findsOneWidget);
    expect(find.text('تعديل الرصيد والصلاحية'), findsOneWidget);
    expect(calls.any((p) => p == 'packages/2/'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance adjustment requires a reason and sends the original state', (tester) async {
    Map<String, dynamic>? sent;
    Future<dynamic> request(String path, String method, Map<String, dynamic>? body) async {
      sent = body;
      expect(path, 'package-purchases/11/adjust/');
      return member();
    }
    await tester.pumpWidget(app(Builder(builder: (context) => TextButton(
      onPressed: () => adjustCustomerPackage(context, member(), request), child: const Text('تعديل')))));
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إضافة غسلة'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'حفظ التعديل')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'سبب التعديل *'), 'تعويض العميل');
    await tester.pump();
    await tester.ensureVisible(find.text('حفظ التعديل'));
    await tester.tap(find.text('حفظ التعديل'));
    await tester.pumpAndSettle();
    expect(sent?['remaining_washes'], 4);
    expect(sent?['expected_remaining_washes'], 3);
    expect(sent?['expected_expires_at'], member()['expires_at']);
    expect(sent?['reason'], 'تعويض العميل');
    expect(sent?['reference'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('package and subscriber controls fit a narrow Arabic screen', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(SingleChildScrollView(child: Column(children: [
      PackagePlanCard(plan: {...plan(1, archived: true), 'name': 'باقة باسم طويل لاختبار القراءة على شاشة الجوال'},
        onManage: () {}, onEdit: () {}, onArchive: () {}),
      PackageMemberCard(item: member(), onEdit: () {}, onRevoke: () {}, onHistory: () {},
        onApprove: () {}, onReject: () {}),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('الغسلات المتبقية: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
