import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/companion_features.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('companion hub routes to true-north Qibla page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CompanionHub())));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('companion_search')), 'Qibla',
    );
    await tester.pumpAndSettle();
    expect(find.text('Qibla Direction'), findsOneWidget);
    await tester.ensureVisible(find.text('Qibla Direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qibla Direction'));
    await tester.pumpAndSettle();
    expect(find.text('Point towards the Kaaba'), findsOneWidget);
    expect(find.textContaining('not a live compass'), findsOneWidget);
  });

  testWidgets('unsourced supplications remain unavailable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ContentLibraryGate(
        title: 'Adhkar & Du’a', type: 'supplications')));
    expect(find.text('Verified sources required'), findsOneWidget);
    expect(find.textContaining('no approved content yet'), findsOneWidget);
  });

  testWidgets('reminder page warns that no alerts are scheduled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReminderSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('NOT'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
  });
}
