import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times.dart';

/// Builds a week of local-city calendar dates using the existing offline
/// astronomical calculator. It does not fetch a calendar or schedule alerts.
///
/// The currently supported cities all have UTC offsets between 0 and +3,
/// so UTC noon maps to the same civil date in each chosen city. Validate
/// actual city dates rather than silently mislabelling a future new city.
class PrayerWeekPlanner {
  PrayerWeekPlanner({PrayerTimeService? service})
      : _service = service ?? PrayerTimeService();

  final PrayerTimeService _service;

  List<PrayerSchedule> build({
    required PrayerCity city,
    required DateTime start,
    required PrayerMethod method,
    required AsrRule asr,
  }) {
    if (start.year < 1900 || start.year > 2099) {
      throw const FormatException('Prayer planner date outside supported range');
    }

    final dates = <PrayerSchedule>[];
    for (var offset = 0; offset < 7; offset++) {
      final noonUtc = DateTime.utc(
        start.year, start.month, start.day + offset, 12,
      );
      final day = _service.forInstant(city, noonUtc, method, asr);
      if (day.date.year != noonUtc.year ||
          day.date.month != noonUtc.month ||
          day.date.day != noonUtc.day) {
        throw StateError('City date differs from requested planning day');
      }
      const eventNames = <String>[
        'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha',
      ];
      if (day.events.length != eventNames.length ||
          day.events.asMap().entries.any(
            (entry) => entry.value.name != eventNames[entry.key],
          ) ||
          day.events.where((event) => event.isObligatory).length != 5) {
        throw StateError('Incomplete prayer schedule');
      }
      dates.add(day);
    }
    return List<PrayerSchedule>.unmodifiable(dates);
  }

  String readableCopy({
    required PrayerCity city,
    required PrayerMethod method,
    required AsrRule asr,
    required List<PrayerSchedule> schedules,
  }) {
    if (schedules.length != 7) {
      throw const FormatException('Expected seven days for export');
    }
    final buffer = StringBuffer()
      ..writeln('SAFWA | Estimated prayer times')
      ..writeln('City: ${city.name} (${city.zone})')
      ..writeln('Method: ${method.label}')
      ..writeln('Asr: ${asr.label}')
      ..writeln('Astronomical estimates, not an official local mosque timetable.')
      ..writeln('Verify with your local mosque. Sunrise is not obligatory.')
      ..writeln();
    for (final day in schedules) {
      buffer.writeln(day.date.toIso8601String().split('T').first);
      for (final event in day.events) {
        final hour = event.at.hour.toString().padLeft(2, '0');
        final minute = event.at.minute.toString().padLeft(2, '0');
        buffer.writeln('  ${event.name}: $hour:$minute');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

class PrayerWeekPage extends StatefulWidget {
  const PrayerWeekPage({super.key});

  @override
  State<PrayerWeekPage> createState() => _PrayerWeekPageState();
}

class _PrayerWeekPageState extends State<PrayerWeekPage> {
  final planner = PrayerWeekPlanner();

  String? cityId;
  PrayerMethod method = PrayerMethod.mwl;
  AsrRule asr = AsrRule.standard;
  bool loading = true;
  late DateTime firstDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    firstDay = DateTime.utc(today.year, today.month, today.day);
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) {
        return;
      }
      setState(() {
        final storedId = prefs.getString('safwa_prayer_city');
        cityId = prayerCities.any((city) => city.id == storedId)
            ? storedId
            : null;
        method = PrayerMethod.values.firstWhere(
          (item) => item.name == prefs.getString('safwa_prayer_method'),
          orElse: () => PrayerMethod.mwl,
        );
        asr = AsrRule.values.firstWhere(
          (item) => item.name == prefs.getString('safwa_prayer_asr'),
          orElse: () => AsrRule.standard,
        );
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cityId != null) {
        if (!await prefs.setString('safwa_prayer_city', cityId!)) {
          throw StateError('City setting not saved');
        }
      }
      if (!await prefs.setString('safwa_prayer_method', method.name) ||
          !await prefs.setString('safwa_prayer_asr', asr.name)) {
        throw StateError('Prayer settings not saved');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save weekly prayer settings.'),
        ));
      }
    }
  }

  void _changeWeek(int weeks) {
    final next = DateTime.utc(
      firstDay.year, firstDay.month, firstDay.day + (7 * weeks),
    );
    if (next.year < 1900 || next.year > 2099) {
      return;
    }
    setState(() => firstDay = next);
  }

  Future<void> _copy(
    PrayerCity city,
    List<PrayerSchedule> schedules,
  ) async {
    final message = planner.readableCopy(
      city: city, method: method, asr: asr, schedules: schedules,
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Estimated seven-day schedule copied.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF142547);
    const gold = Color(0xFFAD8744);
    final selected = prayerCities
        .where((city) => city.id == cityId)
        .firstOrNull;

    List<PrayerSchedule>? week;
    if (!loading && selected != null) {
      try {
        week = planner.build(
          city: selected, start: firstDay, method: method, asr: asr,
        );
      } catch (_) {
        // Fail closed: do not display invented or incomplete times.
      }
    }

    String clock(DateTime instant) =>
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay(hour: instant.hour, minute: instant.minute),
          alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('7-Day Prayer Planner')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(18), children: [
              const Text(
                'Plan your Salah week',
                style: TextStyle(
                  fontSize: 27, fontWeight: FontWeight.w800, color: navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Estimated times calculated offline. Choose your city '
                'manually — no GPS, network access or scheduled alerts.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey('weekly_city_$cityId'),
                initialValue: cityId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'City',
                ),
                items: prayerCities.map((city) => DropdownMenuItem(
                  value: city.id, child: Text(city.name),
                )).toList(),
                onChanged: (value) {
                  setState(() => cityId = value);
                  _save();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PrayerMethod>(
                key: ValueKey('weekly_method_${method.name}'),
                initialValue: method,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Method',
                ),
                items: PrayerMethod.values.map((value) => DropdownMenuItem(
                  value: value, child: Text(value.label),
                )).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => method = value);
                  _save();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AsrRule>(
                key: ValueKey('weekly_asr_${asr.name}'),
                initialValue: asr,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Asr method',
                ),
                items: AsrRule.values.map((value) => DropdownMenuItem(
                  value: value, child: Text(value.label),
                )).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => asr = value);
                  _save();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                IconButton(
                  key: const Key('previous_week'),
                  onPressed: () => _changeWeek(-1),
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: Center(child: Text(
                  'From ${firstDay.toIso8601String().split('T').first}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ))),
                IconButton(
                  key: const Key('next_week'),
                  onPressed: () => _changeWeek(1),
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
              if (selected == null)
                const Card(child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Select a city to see a seven-day schedule.'),
                ))
              else if (week == null)
                const Card(child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Calculation unavailable; no times shown.'),
                ))
              else ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    key: const Key('copy_week'),
                    onPressed: () => _copy(selected, week!),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy 7 days'),
                  ),
                ),
                ...week.map((day) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.date.toIso8601String().split('T').first,
                          style: const TextStyle(
                            color: navy, fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        ...day.events.map((event) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(event.name),
                          subtitle: event.isObligatory
                              ? null
                              : const Text('Sunrise — not an obligatory prayer'),
                          trailing: Text(
                            clock(event.at),
                            style: const TextStyle(
                              color: navy, fontWeight: FontWeight.w700,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                )),
              ],
              const SizedBox(height: 12),
              const Text(
                'These are astronomical estimates, not approved prayer '
                'times. Check against your local mosque calendar before '
                'relying on them. Times use the selected city timezone. '
                'No reminders or Adhan notifications are scheduled.',
                style: TextStyle(fontSize: 12, color: gold),
              ),
            ]),
    );
  }
}
