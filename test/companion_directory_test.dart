import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/companion_directory.dart';
import 'package:safwa_quran/companion_features.dart';
import 'package:safwa_quran/local_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all directory entries have unique stable IDs', () {
    expect(companionItems.length, 13);
    expect(companionIds.length, companionItems.length);
    expect(companionItems.every((item) =>
      item.title.isNotEmpty && item.description.isNotEmpty), isTrue);
  });

  test('search handles title, description and multiple case-insensitive terms',
      () {
    expect(visibleCompanionItems('  QIBLA  ', <String>{}).single.id, 'qibla');
    expect(visibleCompanionItems('weekly journal', <String>{}).single.id,
        'salah_history');
    expect(visibleCompanionItems('audio rights', <String>{}).single.id,
        'recitations');
    expect(visibleCompanionItems('not-a-real-tool', <String>{}), isEmpty);
  });

  test('pinned tools lead without changing normal relative order', () {
    final sorted = visibleCompanionItems('', {'privacy', 'qibla'});
    expect(sorted.take(2).map((item) => item.id),
        ['qibla', 'privacy']);
    expect(sorted[2].id, 'prayer_times');
    expect(sorted.length, companionItems.length);
  });

  test('pinning persists on device and toggles safely', () async {
    const repo = LocalCompanionPins();
    expect(await repo.read(), isEmpty);
    expect(await repo.toggle('qibla'), {'qibla'});
    expect(await repo.toggle('privacy'), {'qibla', 'privacy'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(LocalCompanionPins.storageKey),
        ['qibla', 'privacy']);
    expect(await repo.toggle('qibla'), {'privacy'});
    expect(await repo.read(), {'privacy'});
  });

  test('unknown or corrupted pins cannot become navigation destinations',
      () async {
    SharedPreferences.setMockInitialValues({
      LocalCompanionPins.storageKey: <String>['qibla', 'invalid', 'qibla'],
    });
    const repo = LocalCompanionPins();
    expect(await repo.read(), {'qibla'});
    await expectLater(repo.toggle('unknown_destination'), throwsFormatException);
    expect(await repo.read(), {'qibla'});
  });

  test('new pins are included in allowlisted local backup', () async {
    const repo = LocalCompanionPins();
    await repo.toggle('salah_history');
    await repo.toggle('prayer_week');
    const backup = LocalSafwaBackup();
    final payload = await backup.createBackupJson();
    expect(backup.inspect(payload).keyCount, 1);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LocalCompanionPins.storageKey);
    expect(await repo.read(), isEmpty);
    await backup.restoreBackup(payload, confirmed: true);
    expect(await repo.read(), {'prayer_week', 'salah_history'});
  });

  test('backup rejects unknown or repeated pin IDs before restore', () async {
    const backup = LocalSafwaBackup();
    final doc = jsonDecode(await backup.createBackupJson())
        as Map<String, dynamic>;
    final map = doc['values'] as Map<String, dynamic>;
    map[LocalCompanionPins.storageKey] = ['locked_unreviewed_tool'];
    expect(() => backup.inspect(jsonEncode(doc)), throwsFormatException);
    map[LocalCompanionPins.storageKey] = ['qibla', 'qibla'];
    expect(() => backup.inspect(jsonEncode(doc)), throwsFormatException);
  });

  testWidgets('search shows only matching entries and an accessible count',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CompanionHub()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('companion_search')),
        'Qibla');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('companion_card_qibla')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('companion_card_prayer_times')),
        findsNothing);
    expect(find.text('1 tools found · 0 pinned'), findsOneWidget);
  });

  testWidgets('tapping pin saves shortcut without leaving the hub',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CompanionHub()),
    ));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('companion_search'));
    await tester.enterText(field, 'Qibla');
    await tester.pumpAndSettle();
    final pin = find.byKey(const ValueKey('companion_pin_qibla'));
    await tester.ensureVisible(pin);
    await tester.pumpAndSettle();
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(await const LocalCompanionPins().read(), {'qibla'});
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    final cards = find.byType(Card);
    expect(cards, findsWidgets);
    final firstCard = tester.widget<Card>(cards.first);
    expect(firstCard.key, const ValueKey('companion_card_qibla'));
    expect(find.text('Faith in your daily routine.'), findsOneWidget);
  });

  testWidgets('locked religious content remains locked through search',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CompanionHub()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('companion_search')),
        'Adhkar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adhkar & Du’a'));
    await tester.pumpAndSettle();
    expect(find.text('Verified sources required'), findsOneWidget);
  });
}
