import 'package:flutter/material.dart';

import 'companion_core.dart';

/// A snapshot of only the prayers a person explicitly marked in Safwa.
/// An unmarked item is unknown, never evidence that Salah was missed.
class SalahHistoryDay {
  SalahHistoryDay(DateTime date, Set<String> marked)
      : date = DateTime(date.year, date.month, date.day),
        marked = Set<String>.unmodifiable(marked.where(salahNames.contains));

  final DateTime date;
  final Set<String> marked;
  String get dateKey => civilDateKey(date);
}

/// Reads the existing private device journal; no new account, server or
/// sensor. The displayed week always runs Monday to Sunday (local dates).
class LocalSalahHistory {
  const LocalSalahHistory({this.journal = const LocalSalahJournal()});
  final LocalSalahJournal journal;

  Future<List<SalahHistoryDay>> forWeek(DateTime selectedDate) async {
    if (selectedDate.year < 2000 || selectedDate.year > 2099) {
      throw const FormatException('Date outside supported journal range');
    }
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - (selectedDate.weekday - DateTime.monday),
    );
    final dates = List<DateTime>.generate(
      7, (index) => DateTime(monday.year, monday.month, monday.day + index),
      growable: false,
    );
    final marked = await Future.wait(dates.map(journal.read));
    return List<SalahHistoryDay>.unmodifiable([
      for (var i = 0; i < 7; i++) SalahHistoryDay(dates[i], marked[i]),
    ]);
  }
}

class SalahHistoryPage extends StatefulWidget {
  const SalahHistoryPage({super.key});

  @override
  State<SalahHistoryPage> createState() => _SalahHistoryPageState();
}

class _SalahHistoryPageState extends State<SalahHistoryPage> {
  final history = const LocalSalahHistory();
  final journal = const LocalSalahJournal();

  late DateTime selectedWeek;
  List<SalahHistoryDay> days = const [];
  bool loading = true;
  String? error;
  String? savingKey;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedWeek = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await history.forWeek(selectedWeek);
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        days = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        days = const [];
        error = 'Could not read the private journal on this device.';
        loading = false;
      });
    }
  }

  void _moveWeek(int weeks) {
    if (savingKey != null) return;
    final date = DateTime(
      selectedWeek.year, selectedWeek.month, selectedWeek.day + weeks * 7,
    );
    if (date.year < 2000 || date.year > 2099) return;
    selectedWeek = date;
    _load();
  }

  void _thisWeek() {
    if (savingKey != null) return;
    final now = DateTime.now();
    selectedWeek = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _toggle(SalahHistoryDay day, String prayer) async {
    if (savingKey != null || loading) return;
    final key = '${day.dateKey}:$prayer';
    setState(() => savingKey = key);
    try {
      final marked = await journal.toggle(day.date, prayer);
      if (!mounted) return;
      // Don't overwrite a newer week when a storage write finishes.
      if (days.any((candidate) => candidate.dateKey == day.dateKey)) {
        setState(() {
          days = List<SalahHistoryDay>.unmodifiable([
            for (final candidate in days)
              candidate.dateKey == day.dateKey
                  ? SalahHistoryDay(day.date, marked)
                  : candidate,
          ]);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to update the private journal.'),
        ));
      }
    } finally {
      if (mounted) setState(() => savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF142547);
    const teal = Color(0xFF187A8B);
    const gold = Color(0xFFAD8744);
    const weekdays = <String>[
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Salah Journal')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text(
          'Your private weekly journal',
          style: TextStyle(
            color: navy, fontSize: 26, fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Only entries you mark are recorded. Empty boxes mean '
          '“not recorded”, never “missed” or a religious judgment. '
          'Your entries stay in the existing local Safwa journal.',
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(
            key: const Key('history_previous_week'),
            onPressed: savingKey == null && !loading
                ? () => _moveWeek(-1) : null,
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: Center(child: Text(
            days.isEmpty
                ? 'Weekly journal'
                : '${days.first.dateKey} to ${days.last.dateKey}',
            style: const TextStyle(
              color: navy, fontWeight: FontWeight.w700,
            ),
          ))),
          IconButton(
            key: const Key('history_next_week'),
            onPressed: savingKey == null && !loading
                ? () => _moveWeek(1) : null,
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        Center(child: TextButton(
          key: const Key('history_this_week'),
          onPressed: savingKey == null && !loading ? _thisWeek : null,
          child: const Text('This week'),
        )),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(error!, key: const Key('history_error')),
          ))
        else ...[
          Semantics(
            label: 'Optional entries recorded in these seven days',
            child: Text(
              '${days.fold<int>(0, (sum, day) => sum + day.marked.length)} '
              '${days.fold<int>(0, (sum, day) => sum + day.marked.length) == 1 ? 'personal entry' : 'personal entries'} '
              'recorded this week',
              key: const Key('history_total'),
              style: const TextStyle(
                color: teal, fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...days.map((day) => Card(
            child: ExpansionTile(
              key: ValueKey('history_day_${day.dateKey}'),
              title: Text(
                '${weekdays[day.date.weekday - 1]} · ${day.dateKey}',
                style: const TextStyle(
                  color: navy, fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                day.marked.isEmpty
                    ? 'No entries recorded'
                    : '${day.marked.length} entries marked by you',
              ),
              children: [
                for (final prayer in salahNames)
                  CheckboxListTile(
                    key: ValueKey('history_${day.dateKey}_$prayer'),
                    title: Text(prayer),
                    subtitle: Text(
                      day.marked.contains(prayer)
                          ? 'Marked by you' : 'Not recorded',
                    ),
                    secondary: const Icon(
                      Icons.check_circle_outline, color: gold,
                    ),
                    value: day.marked.contains(prayer),
                    onChanged: savingKey == null && !loading
                        ? (_) => _toggle(day, prayer)
                        : null,
                  ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          const Text(
            'These are optional personal notes, not an assessment '
            'of worship. No scores, streaks, uploads, GPS, '
            'notifications or automatic sharing. Delete Safwa data '
            'using Privacy & Data if needed.',
            style: TextStyle(fontSize: 12, color: navy),
          ),
        ],
      ]),
    );
  }
}
