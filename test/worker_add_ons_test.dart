import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwash_app/widgets/worker_add_ons.dart';
import 'package:carwash_app/worker_localization.dart';

void main() {
  testWidgets('selected extras are readable in all worker languages on mobile', (tester) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in WorkerLanguage.values) {
      final l = WorkerLocalizations(language);
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: l.textDirection,
        child: Scaffold(body: SingleChildScrollView(child: WorkerAddOns(
          localizations: l,
          addOns: const [
            {'name': 'ملمع كفرات فاخر', 'quantity': 1},
            {'name': 'واكس (شامبو)', 'quantity': 2},
            {'name': 'تكييس الوطايات', 'quantity': 1},
          ],
        ))),
      )));
      expect(find.text(l.serviceName('ملمع كفرات فاخر')), findsOneWidget);
      expect(find.text(l.serviceName('واكس (شامبو)')), findsOneWidget);
      expect(find.text(l.serviceName('تكييس الوطايات')), findsOneWidget);
      expect(find.text('${l.quantity}: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('empty extras are explicit and future extras remain visible', (tester) async {
    final l = WorkerLocalizations(WorkerLanguage.en);
    Future<void> show(List<Map<String, dynamic>> extras) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WorkerAddOns(addOns: extras, localizations: l))));
    await show([]);
    expect(find.text('No additional services'), findsOneWidget);
    await show([{'name': 'New service', 'quantity': 3}]);
    expect(find.text('New service'), findsOneWidget);
    expect(find.text('Quantity: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
