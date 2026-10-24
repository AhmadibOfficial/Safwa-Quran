import 'package:flutter/material.dart';
import 'safwa_preferences.dart';

import 'companion_core.dart';
import 'companion_directory.dart';
import 'prayer_times.dart';
import 'prayer_week.dart';
import 'secure_backup_page.dart';
import 'salah_history.dart';

const _navy = Color(0xFF142547);
const _gold = Color(0xFFAD8744);
const _teal = Color(0xFF187A8B);

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class CompanionHub extends StatefulWidget {
  const CompanionHub({super.key});

  @override
  State<CompanionHub> createState() => _CompanionHubState();
}

class _CompanionHubState extends State<CompanionHub> {
  final pinsStore = const LocalCompanionPins();
  Set<String> pinned = <String>{};
  String search = '';
  bool busy = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final result = await pinsStore.read();
      if (mounted) setState(() { pinned = result; loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load saved companion pins.'),
        ));
      }
    }
  }

  Future<void> _togglePin(String id) async {
    if (busy || loading) return;
    setState(() => busy = true);
    try {
      final result = await pinsStore.toggle(id);
      if (mounted) setState(() => pinned = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save the companion pin locally.'),
        ));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _pageFor(String id) => switch (id) {
    'prayer_times' => const PrayerTimesPage(),
    'prayer_week' => const PrayerWeekPage(),
    'qibla' => const QiblaPage(),
    'reminders' => const ReminderSettingsPage(),
    'salah_journal' => const SalahJournalPage(),
    'salah_history' => const SalahHistoryPage(),
    'tasbih' => const TasbihPage(),
    'hijri' => const HijriCalendarPage(),
    'adhkar' => const ContentLibraryGate(
      title: 'Adhkar & Du’a', type: 'supplications',
    ),
    'recitations' => const ContentLibraryGate(
      title: 'Quran Recitations', type: 'recitation audio',
    ),
    'learning' => const LearningPlanPage(),
    'languages' => const LanguagePreferencesPage(),
    'privacy' => const PrivacyPage(),
    _ => throw const FormatException('Unknown companion destination'),
  };

  IconData _iconFor(String id) => switch (id) {
    'prayer_times' => Icons.access_time,
    'prayer_week' => Icons.date_range_outlined,
    'qibla' => Icons.explore_outlined,
    'reminders' => Icons.notifications_none,
    'salah_journal' => Icons.check_circle_outline,
    'salah_history' => Icons.view_week_outlined,
    'tasbih' => Icons.touch_app_outlined,
    'hijri' => Icons.calendar_month_outlined,
    'adhkar' => Icons.favorite_border,
    'recitations' => Icons.headphones_outlined,
    'learning' => Icons.school_outlined,
    'languages' => Icons.language_outlined,
    'privacy' => Icons.privacy_tip_outlined,
    _ => Icons.apps_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final visible = visibleCompanionItems(search, pinned);
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('SAFWA INSTITUTE / YOUR COMPANION',
        style: TextStyle(color: _teal, fontSize: 11,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('Faith in your daily routine.',
        style: TextStyle(color: _navy, fontSize: 28,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      const Text('Tools work offline where possible. Quran and other '
        'religious content remain locked until independently reviewed.'),
      const SizedBox(height: 16),
      TextField(
        key: const Key('companion_search'),
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          labelText: 'Find a companion tool',
          hintText: 'Search prayer, journal, learning...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => search = value),
      ),
      const SizedBox(height: 12),
      Semantics(
        liveRegion: true,
        child: Text(
          loading
            ? 'Loading saved tools'
            : '${visible.length} tools found · ${pinned.length} pinned',
          key: const Key('companion_result_count'),
          style: const TextStyle(color: _teal),
        ),
      ),
      const SizedBox(height: 12),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (visible.isEmpty)
        const Card(child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No companion tools match your search.'),
        ))
      else
        ...visible.map((item) => Card(
          key: ValueKey('companion_card_${item.id}'),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF1ECE1),
              child: Icon(_iconFor(item.id), color: _navy),
            ),
            title: Text(item.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.description),
            trailing: IconButton(
              key: ValueKey('companion_pin_${item.id}'),
              tooltip: pinned.contains(item.id)
                  ? 'Unpin ${item.title}'
                  : 'Pin ${item.title}',
              onPressed: busy ? null : () => _togglePin(item.id),
              icon: Icon(
                pinned.contains(item.id)
                    ? Icons.star : Icons.star_border,
                color: _gold,
              ),
            ),
            onTap: () => _open(context, _pageFor(item.id)),
          ),
        )),
      const SizedBox(height: 12),
      const Text('Pinned items are navigation shortcuts, not endorsements '
        'or unlocked religious content. Pins are saved on this device.',
        style: TextStyle(color: _navy, fontSize: 12)),
    ]);
  }
}

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});
  @override State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  String? selectedCity;
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SafwaPreferences.getInstance();
    if (!mounted) return;
    final id = prefs.getString('safwa_prayer_city');
    setState(() {
      selectedCity = prayerCities.any((c) => c.id == id) ? id : null;
      loading = false;
    });
  }
  @override Widget build(BuildContext context) {
    PrayerCity? city;
    for (final item in prayerCities) {
      if (item.id == selectedCity) city = item;
    }
    double? bearing;
    if (city != null) {
      try {
        bearing = qiblaBearing(city.latitude, city.longitude);
      } catch (_) {
        // City-center coordinate may be too close to the Kaaba to define a bearing.
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Qibla Direction')),
      body: loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Point towards the Kaaba',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800,
              color: _navy)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedCity,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(), labelText: 'Manual city'),
            items: prayerCities.map((c) => DropdownMenuItem(
              value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) async {
              setState(() => selectedCity = v);
              final prefs = await SafwaPreferences.getInstance();
              if (v != null) await prefs.setString('safwa_prayer_city', v);
            },
          ),
          const SizedBox(height: 18),
          if (bearing == null)
            const Card(child: Padding(padding: EdgeInsets.all(18),
              child: Text('Select a city to calculate a Qibla bearing.')))
          else Card(child: Padding(padding: const EdgeInsets.all(25),
            child: Column(children: [
              const Icon(Icons.explore_outlined, size: 74, color: _gold),
              const SizedBox(height: 12),
              Text('${bearing.toStringAsFixed(1)}°',
                style: const TextStyle(fontSize: 46, color: _navy,
                  fontWeight: FontWeight.w900)),
              const Text('CLOCKWISE FROM TRUE NORTH'),
              const SizedBox(height: 10),
              Text(city!.name, textAlign: TextAlign.center),
            ]))),
          const SizedBox(height: 20),
          const Text('This is a geographic bearing, not a live compass. '
              'Your device is not reading magnetic north or calibrating a '
              'sensor. A magnetic compass requires local declination '
              'correction. City-center coordinates are approximate.',
            style: TextStyle(color: _navy)),
        ]),
    );
  }
}

class SalahJournalPage extends StatefulWidget {
  const SalahJournalPage({super.key});
  @override State<SalahJournalPage> createState() => _SalahJournalPageState();
}

class _SalahJournalPageState extends State<SalahJournalPage> {
  final store = const LocalSalahJournal();
  DateTime day = DateTime.now();
  Set<String> recorded = {};
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final result = await store.read(day);
    if (mounted) {
      setState(() { recorded = result; loading = false; });
    }
  }
  Future<void> _chooseDay() async {
    final chosen = await showDatePicker(context: context,
      initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (chosen == null) return;
    setState(() { day = chosen; loading = true; });
    await _load();
  }
  Future<void> _toggle(String prayer) async {
    try {
      final updated = await store.toggle(day, prayer);
      if (mounted) {
        setState(() => recorded = updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the local journal.')));
      }
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Salah Journal')),
    body: loading ? const Center(child: CircularProgressIndicator())
    : ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Your personal prayer log',
        style: TextStyle(color: _navy, fontSize: 24,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('This optional record is private. An unchecked prayer '
          'means not recorded, not automatically missed or judged.'),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: _chooseDay,
        icon: const Icon(Icons.date_range_outlined),
        label: Text(civilDateKey(day))),
      const SizedBox(height: 14),
      ...salahNames.map((name) => Card(child: CheckboxListTile(
        title: Text(name), value: recorded.contains(name),
        secondary: const Icon(Icons.access_time, color: _gold),
        onChanged: (_) => _toggle(name),
      ))),
      const SizedBox(height: 16),
      Text('${recorded.length} of 5 marked by you',
          style: const TextStyle(color: _teal)),
    ]),
  );
}

class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});
  @override State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  final store = const LocalTasbih();
  int count = 0, goal = 33;
  bool busy = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final values = await Future.wait([store.count(), store.goal()]);
    if (mounted) {
      setState(() {
        count = values[0]; goal = values[1]; busy = false;
      });
    }
  }
  Future<void> _advance() async {
    try {
      final value = await store.increment();
      if (mounted) {
        setState(() => count = value);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Counter could not be saved.')));
      }
    }
  }
  Future<void> _reset() async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset counter?'),
        content: const Text('This clears your stored count on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset')),
        ]));
    if (confirm != true) return;
    await store.reset();
    if (mounted) {
      setState(() => count = 0);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tasbih Counter')),
    body: busy ? const Center(child: CircularProgressIndicator())
      : Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Personal dhikr counter', style: TextStyle(
            color: _navy, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 25),
          Semantics(label: 'Current count', child: Text(count.toString(),
            style: const TextStyle(fontSize: 80, color: _navy,
              fontWeight: FontWeight.w900))),
          Text('Personal target: $goal'),
          const SizedBox(height: 20),
          SizedBox(width: 220, height: 64,
            child: FilledButton(onPressed: _advance,
              child: const Text('Count +1', style: TextStyle(fontSize: 23)))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: [
            OutlinedButton(onPressed: () async {
              final g = goal == 33 ? 99 : 33;
              await store.setGoal(g);
              if (mounted) {
                setState(() => goal = g);
              }
            }, child: const Text('Switch goal 33 / 99')),
            TextButton(onPressed: _reset, child: const Text('Reset')),
          ]),
          const SizedBox(height: 10),
          const Text('Targets are optional personal preferences, '
              'not a religious prescription.', textAlign: TextAlign.center),
        ]))),
  );
}

class HijriCalendarPage extends StatefulWidget {
  const HijriCalendarPage({super.key});
  @override State<HijriCalendarPage> createState() =>
    _HijriCalendarPageState();
}

class _HijriCalendarPageState extends State<HijriCalendarPage> {
  DateTime chosen = DateTime.now();
  int adjust = 0;
  @override Widget build(BuildContext context) {
    EstimatedHijriDate? result;
    try { result = approximateHijri(chosen, adjustmentDays: adjust); }
    catch (_) { /* never invent a conversion */ }
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Calendar')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Hijri date estimate', style: TextStyle(color: _navy,
          fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Gregorian: ${civilDateKey(chosen)}'),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(20),
          child: Text(result?.label ?? 'Date unavailable',
            style: const TextStyle(color: _navy, fontSize: 23,
              fontWeight: FontWeight.w700)))),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: () async {
          final date = await showDatePicker(context: context,
            initialDate: chosen, firstDate: DateTime(1900),
            lastDate: DateTime(2200));
          if (date != null && mounted) {
            setState(() => chosen = date);
          }
        }, icon: const Icon(Icons.event), label: const Text('Choose date')),
        const SizedBox(height: 12),
        const Text('Local sighting adjustment (days):'),
        SegmentedButton<int>(segments: const [
          ButtonSegment(value: -2, label: Text('-2')),
          ButtonSegment(value: -1, label: Text('-1')),
          ButtonSegment(value: 0, label: Text('0')),
          ButtonSegment(value: 1, label: Text('+1')),
          ButtonSegment(value: 2, label: Text('+2')),
        ], selected: {adjust}, onSelectionChanged: (s) =>
          setState(() => adjust = s.first)),
        const SizedBox(height: 20),
        const Text('This uses a tabular civil calendar, NOT local moon '
          'sighting or an official Ramadan / Eid declaration. '
          'Dates may differ; always consult your local recognized '
          'religious authority for observances.'),
      ]),
    );
  }
}

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override State<ReminderSettingsPage> createState() =>
      _ReminderSettingsPageState();
}
class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  final repository = const PrayerReminderPreferences();
  Map<String,bool> wants = {};
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final values = <String,bool>{};
    for (final prayer in salahNames) {
      values[prayer] = await repository.enabled(prayer);
    }
    if (mounted) {
      setState(() { wants = values; loading = false; });
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prayer Reminders')),
    body: loading ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Choose reminders for later', style: TextStyle(
            color: _navy, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(16),
            child: Text('Important: Notification scheduling is NOT '
              'implemented. These switches save local preferences '
              'only; you will receive NO alerts yet.')),
          ),
          ...salahNames.map((prayer) => SwitchListTile(
            title: Text(prayer),
            subtitle: const Text('Preference stored; alert not active'),
            value: wants[prayer] ?? false,
            onChanged: (enabled) async {
              try {
                await repository.save(prayer, enabled);
                if (mounted) {
                  setState(() => wants[prayer] = enabled);
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not save preference.')));
                }
              }
            },
          )),
          const Text('Adhan audio, OS notifications, permissions and '
              'quiet hours require a later validated integration.'),
        ]),
  );
}

class ContentLibraryGate extends StatelessWidget {
  const ContentLibraryGate({super.key,
    required this.title, required this.type});
  final String title;
  final String type;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Padding(padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_user_outlined, color: _gold, size: 68),
        const SizedBox(height: 18),
        const Text('Verified sources required', style: TextStyle(
            color: _navy, fontSize: 23, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Text('This $type library has no approved content yet. '
          'It will remain empty until source references, usage rights, '
          'qualified religious review and integrity checks are complete.',
          textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text('No invented duas, translations, Quran verses, '
          'or unlicensed recitation audio are distributed.',
          textAlign: TextAlign.center),
      ]))),
  );
}

class LearningPlanPage extends StatefulWidget {
  const LearningPlanPage({super.key});
  @override State<LearningPlanPage> createState() => _LearningPlanPageState();
}
class _LearningPlanPageState extends State<LearningPlanPage> {
  static const topics = <String>[
    'Arabic reading foundations', 'Tajwid terminology',
    'Memorization planning', 'Daily revision routine',
    'Finding reliable references', 'Teacher-guided assessment',
  ];
  Set<String> completed = {};
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SafwaPreferences.getInstance();
    if (mounted) {
      setState(() {
        completed = (p.getStringList('safwa_learning_progress') ?? [])
            .where(topics.contains).toSet();
        loading = false;
      });
    }
  }
  Future<void> _toggle(String topic) async {
    final result = {...completed};
    if (!result.add(topic)) result.remove(topic);
    final p = await SafwaPreferences.getInstance();
    if (await p.setStringList('safwa_learning_progress',
        topics.where(result.contains).toList()) && mounted) {
      setState(() => completed = result);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Learning Plan')),
    body: loading ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Your learning journey', style: TextStyle(
          color: _navy, fontWeight: FontWeight.w800, fontSize: 25)),
        const SizedBox(height: 10),
        const Text('Track your own study topics. These are planning '
          'headings only; theological lesson content is pending '
          'qualified teacher review.'),
        const SizedBox(height: 16),
        ...topics.map((topic) => Card(child: CheckboxListTile(
          title: Text(topic), value: completed.contains(topic),
          onChanged: (_) => _toggle(topic),
        ))),
      ]),
  );
}

class LanguagePreferencesPage extends StatefulWidget {
  const LanguagePreferencesPage({super.key});
  @override State<LanguagePreferencesPage> createState() =>
      _LanguagePreferencesPageState();
}
class _LanguagePreferencesPageState extends State<LanguagePreferencesPage> {
  String selected = 'en';
  @override void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final p = await SafwaPreferences.getInstance();
    if (mounted) {
      setState(() {
        final candidate = p.getString('safwa_language');
        if (<String>{'en','ha','ar'}.contains(candidate)) {
          selected = candidate!;
        }
      });
    }
  }
  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;
    final prefs = await SafwaPreferences.getInstance();
    if (await prefs.setString('safwa_language', value) && mounted) {
      setState(() => selected = value);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Languages')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Preferred interface language',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700,
          color: _navy)),
      const SizedBox(height: 10),
      const Text('Preference is saved locally. Complete localization '
          'and independently checked religious translations '
          'are not yet available.'),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: _changeLanguage,
        child: Column(children: const [
          RadioListTile<String>(title: Text('English'), value: 'en'),
          RadioListTile<String>(title: Text('Hausa'), value: 'ha'),
          RadioListTile<String>(title: Text('العربية'), value: 'ar'),
        ]),
      ),
    ]),
  );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _delete(BuildContext context) async {
    final approved = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Safwa local data?'),
        content: const Text('This removes saved Surahs, ayah bookmarks, '
          'reading progress, prayer city, Salah journal, Tasbih and '
          'learning preferences stored on this device. '
          'This cannot be undone. Quran source files are unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete local data')),
        ],
      ));
    if (approved != true) return;
    try {
      final count = await clearSafwaLocalData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Removed $count local settings. '
            'Restart this screen to refresh its view.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete all local data.')));
      }
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Data')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Your data stays on this device',
        style: TextStyle(color: _navy, fontSize: 25,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      const Text('This feature suite does not require an account or '
          'upload Salah journal entries. Your selected city, preferences '
          'and progress are stored using local app preferences.'),
      const SizedBox(height: 16),
      const Text('Local preferences are not encrypted backups. Avoid '
          'recording sensitive notes here; device backups and other '
          'installed software may affect privacy.'),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        key: const Key('privacy_backup_restore'),
        onPressed: () => _open(context, const SecureBackupPage()),
        icon: const Icon(Icons.backup_outlined),
        label: const Text('Protected local backup & restore'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _delete(context),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete Safwa local preferences'),
      ),
    ]),
  );
}
