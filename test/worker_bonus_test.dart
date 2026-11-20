import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:carwash_app/widgets/worker_bonus_card.dart';
import 'package:carwash_app/worker_localization.dart';

void main() {
  testWidgets('bonus displays current amount and changes language without losing value', (tester) async {
    final client = MockClient((_) async => http.Response(jsonEncode({'month':'2026-11','amount':'125.50','currency':'SAR'}),200));
    final key = GlobalKey<WorkerBonusCardState>();
    await http.runWithClient(() async {
      for (final language in WorkerLanguage.values) {
        final l=WorkerLocalizations(language);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkerBonusCard(key:key,baseUrl:'https://example.com',localizations:l))));
        await tester.pump();
        expect(find.text(l.monthlyBonus),findsOneWidget);
        expect(find.text('125.50 ${l.bonusCurrency}'),findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },()=>client);
    client.close();
  });

  testWidgets('monthly rollover refreshes zero rather than showing last months amount', (tester) async {
    var nextMonth=false;
    final client=MockClient((_) async => http.Response(jsonEncode({'month':nextMonth?'2026-12':'2026-11','amount':nextMonth?'0.00':'75.00','currency':'SAR'}),200));
    final key=GlobalKey<WorkerBonusCardState>();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkerBonusCard(key:key,baseUrl:'https://example.com',localizations:WorkerLocalizations(WorkerLanguage.en)))));
      await tester.pump();
      expect(find.text('75.00 SAR'),findsOneWidget);
      nextMonth=true;
      await key.currentState!.refresh();
      await tester.pump();
      expect(find.text('0.00 SAR'),findsOneWidget);
      expect(find.text('75.00 SAR'),findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },()=>client);
    client.close();
  });
}
