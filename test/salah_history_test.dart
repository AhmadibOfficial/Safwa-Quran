import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/companion_core.dart';
import 'package:safwa_quran/companion_features.dart';
import 'package:safwa_quran/salah_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('weekly history covers Monday to Sunday across a year boundary',
      () async {
    const history = LocalSalahHistory();
    final days = await history.forWeek(DateTime(2026, 12, 31));
    expect(days.length, 7);
    expect(days.first.dateKey, '2026-12-28');
    expect(days.last.dateKey, '2027-01-03');
    expect(days.every((day) => day.marked.isEmpty), isTrue);
  });

  test('history reads only explicitly saved local user entries', () async {
    const journal = LocalSalahJournal();
    await journal.toggle(DateTime(2026, 10, 19), 'Fajr');
    await journal.toggle(DateTime(2026, 10, 21), 'Isha');
    final days = await const LocalSalahHistory().forWeek(
      DateTime(2026, 10, 22),
    );
    expect(days[0].dateKey, '2026-10-19');
    expect(days[0].marked, {'Fajr'});
    expect(days[1].marked, isEmpty);
    expect(days[2].marked, {'Isha'});
    expect(days[6].marked, isEmpty);
    expect(days.fold<int>(0, (sum, d) => sum + d.marked.length), 2);
  });

  test('unknown and malformed prayer names never appear in history',
      () async {
    SharedPreferences.setMockInitialValues({
      'safwa_salah_2026-10-19': <String>['Fajr', 'Sunrise', 'untrusted', 'Fajr'],
      'unrelated_app_setting': 'keep',
    });
    final monday = (await const LocalSalahHistory().forWeek(
      DateTime(2026, 10, 19),
    )).first;
    expect(monday.marked, {'Fajr'});
    expect(() => monday.marked.add('Isha'), throwsUnsupportedError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unrelated_app_setting'), 'keep');
  });

  test('journal deletion clears history without affecting unrelated data',
      () async {
    SharedPreferences.setMockInitialValues({
      'safwa_salah_2026-10-19': <String>['Fajr'],
      'unrelated_app_setting': 'keep',
    });
    expect(
      (await const LocalSalahHistory().forWeek(
        DateTime(2026, 10, 19),
      )).first.marked,
      {'Fajr'},
    );
    final removed = await clearSafwaLocalData();
    expect(removed, 1);
    expect(
      (await const LocalSalahHistory().forWeek(
        DateTime(2026, 10, 19),
      )).first.marked,
      isEmpty,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unrelated_app_setting'), 'keep');
  });

  test('out-of-range journal dates are refused', () async {
    await expectLater(
      const LocalSalahHistory().forWeek(DateTime(1999, 12, 31)),
      throwsFormatException,
    );
    await expectLater(
      const LocalSalahHistory().forWeek(DateTime(2100, 1, 1)),
      throwsFormatException,
    );
  });

  test('changing a day updates an existing week, not other days',
      () async {
    const journal = LocalSalahJournal();
    final date = DateTime(2026, 10, 23);
    await journal.toggle(date, 'Dhuhr');
    final days = await const LocalSalahHistory().forWeek(date);
    expect(days[4].marked, {'Dhuhr'});
    await journal.toggle(date, 'Dhuhr');
    final after = await const LocalSalahHistory().forWeek(date);
    expect(after[4].marked, isEmpty);
    expect(after[0].marked, isEmpty);
  });

  testWidgets('empty history displays neutral not-recorded wording',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SalahHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Salah Journal'), findsOneWidget);
    expect(find.text('No entries recorded'), findsWidgets);
    expect(find.textContaining('Empty boxes mean'), findsOneWidget);
    expect(find.byKey(const Key('history_total')), findsOneWidget);
  });

  testWidgets('expanding first weekday and marking a prayer persists locally',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SalahHistoryPage()));
    await tester.pumpAndSettle();
    // Use the first day of the displayed week. It is initially visible
    // within Flutter's default 800x600 test viewport; a later weekday's
    // ExpansionTile can be partly below the viewport after a drag.
    final now = DateTime.now();
    final monday = DateTime(
      now.year, now.month, now.day - (now.weekday - DateTime.monday),
    );
    final mondayKey = civilDateKey(monday);
    final title = find.text('Monday · $mondayKey');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pumpAndSettle();

    final checkbox = find.byKey(ValueKey('history_${mondayKey}_Fajr'));
    expect(checkbox, findsOneWidget);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // Verify persistence first. Expanding the day scrolls the summary
    // out of Flutter's compact widget-test viewport, so scroll back to
    // the actual header before asserting that the rendered total updated.
    expect(await const LocalSalahJournal().read(monday), contains('Fajr'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_total')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final total = find.byKey(const Key('history_total'));
    expect(total, findsOneWidget);
    expect(
      tester.widget<Text>(total).data,
      '1 personal entry recorded this week',
    );
  });

  testWidgets('companion hub opens private history without location access',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompanionHub())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('companion_search')), 'Weekly Salah',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Weekly Salah Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly Salah Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Your private weekly journal'), findsOneWidget);
  });
}
