import 'package:shared_preferences/shared_preferences.dart';

/// Names and descriptions of the existing offline-first Safwa tools.
/// This directory never changes Quran source approval or unlocks content.
class CompanionItem {
  const CompanionItem(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

const companionItems = <CompanionItem>[
  CompanionItem('prayer_times', 'Prayer Times',
      'Offline times and next Salah'),
  CompanionItem('prayer_week', '7-Day Prayer Planner',
      'Offline weekly Salah estimates and a copyable schedule'),
  CompanionItem('qibla', 'Qibla Direction',
      'True-north bearing from a chosen city'),
  CompanionItem('reminders', 'Prayer Reminders',
      'Save reminder preferences — alerts not yet scheduled'),
  CompanionItem('salah_journal', 'My Salah Journal',
      'Private, optional daily prayer log'),
  CompanionItem('salah_history', 'Weekly Salah Journal',
      'Review or update your private entries across seven days'),
  CompanionItem('tasbih', 'Tasbih Counter',
      'Private dhikr counting tool'),
  CompanionItem('hijri', 'Islamic Calendar',
      'Approximate civil Hijri dates'),
  CompanionItem('adhkar', 'Adhkar & Du’a',
      'Authentic source review required'),
  CompanionItem('recitations', 'Quran Recitations',
      'Audio rights and reciter review required'),
  CompanionItem('learning', 'Tajwid & Learning',
      'Personal study planner; lessons pending review'),
  CompanionItem('languages', 'Languages',
      'Save preferred language; translations pending'),
  CompanionItem('privacy', 'Privacy & Data',
      'Offline storage and account-free experience'),
];

final Set<String> companionIds = Set<String>.unmodifiable(
  companionItems.map((item) => item.id),
);

/// Search title/description and sort pinned entries before normal entries.
/// Matching is case-insensitive and requires *all* query terms.
List<CompanionItem> visibleCompanionItems(
  String query,
  Set<String> pinned,
) {
  final terms = query.toLowerCase().trim().split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty).toList();
  final filtered = companionItems.where((item) {
    final text = (item.title + ' ' + item.description).toLowerCase();
    return terms.every(text.contains);
  }).toList();
  filtered.sort((a, b) {
    final aRank = pinned.contains(a.id) ? 0 : 1;
    final bRank = pinned.contains(b.id) ? 0 : 1;
    if (aRank != bRank) return aRank.compareTo(bRank);
    // Preserve original editorial order within pinned/unpinned groups.
    return companionItems.indexOf(a).compareTo(companionItems.indexOf(b));
  });
  return List<CompanionItem>.unmodifiable(filtered);
}

/// A person's navigation pins. No account, sync or personal activity logs.
class LocalCompanionPins {
  const LocalCompanionPins();
  static const storageKey = 'safwa_companion_pins';

  Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(storageKey) ?? const <String>[])
        .where(companionIds.contains).toSet();
  }

  Future<Set<String>> toggle(String id) async {
    if (!companionIds.contains(id)) {
      throw const FormatException('Unknown Safwa companion item');
    }
    final prefs = await SharedPreferences.getInstance();
    final updated = await read();
    if (!updated.add(id)) updated.remove(id);
    final ordered = companionItems
        .where((item) => updated.contains(item.id))
        .map((item) => item.id)
        .toList();
    if (!await prefs.setStringList(storageKey, ordered)) {
      throw StateError('Could not save pinned tools locally');
    }
    return Set<String>.unmodifiable(updated);
  }
}
