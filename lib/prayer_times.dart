import 'package:adhan_dart/adhan_dart.dart' as ad;
import 'package:flutter/material.dart';
import 'safwa_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Explicit manual city selection; no GPS, location permission or network.
class PrayerCity {
  const PrayerCity(this.id, this.name, this.latitude, this.longitude, this.zone);
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String zone;
}

const prayerCities = <PrayerCity>[
  PrayerCity('kaduna', 'Kaduna, Nigeria', 10.5105, 7.4165, 'Africa/Lagos'),
  PrayerCity('abuja', 'Abuja, Nigeria', 9.0765, 7.3986, 'Africa/Lagos'),
  PrayerCity('kano', 'Kano, Nigeria', 12.0022, 8.5920, 'Africa/Lagos'),
  PrayerCity('lagos', 'Lagos, Nigeria', 6.5244, 3.3792, 'Africa/Lagos'),
  PrayerCity('makkah', 'Makkah, Saudi Arabia', 21.3891, 39.8579, 'Asia/Riyadh'),
  PrayerCity('doha', 'Doha, Qatar', 25.2854, 51.5310, 'Asia/Qatar'),
  PrayerCity('london', 'London, UK', 51.5074, -0.1278, 'Europe/London'),
];

enum PrayerMethod {
  mwl('Muslim World League'),
  egyptian('Egyptian General Authority'),
  karachi('Karachi'),
  ummAlQura('Umm al-Qura'),
  isna('ISNA');

  const PrayerMethod(this.label);
  final String label;
}

enum AsrRule {
  standard('Standard / earlier Asr'),
  hanafi('Hanafi / later Asr');

  const AsrRule(this.label);
  final String label;
}

class PrayerEvent {
  const PrayerEvent(this.name, this.at, {this.isObligatory = true});
  final String name;
  final DateTime at;
  final bool isObligatory;
}

class PrayerSchedule {
  const PrayerSchedule(this.date, this.events);
  final DateTime date;
  final List<PrayerEvent> events;
}

/// Uses Adhan astronomical calculations and full IANA timezone rules offline.
/// These are estimates, NOT mosque-certified or religiously approved times.
class PrayerTimeService {
  static bool _zonesInitialized = false;

  tz.Location _location(PrayerCity city) {
    if (!_zonesInitialized) {
      tzdata.initializeTimeZones();
      _zonesInitialized = true;
    }
    return tz.getLocation(city.zone);
  }

  ad.CalculationParameters _parameters(PrayerMethod method, AsrRule asr) {
    final p = switch (method) {
      PrayerMethod.mwl => ad.CalculationMethodParameters.muslimWorldLeague(),
      PrayerMethod.egyptian => ad.CalculationMethodParameters.egyptian(),
      PrayerMethod.karachi => ad.CalculationMethodParameters.karachi(),
      PrayerMethod.ummAlQura => ad.CalculationMethodParameters.ummAlQura(),
      PrayerMethod.isna => ad.CalculationMethodParameters.northAmerica(),
    };
    p.madhab = asr == AsrRule.hanafi ? ad.Madhab.hanafi : ad.Madhab.shafi;
    return p;
  }

  PrayerSchedule forInstant(
      PrayerCity city, DateTime instant, PrayerMethod method, AsrRule asr) {
    if (!city.latitude.isFinite || !city.longitude.isFinite ||
        city.latitude.abs() > 90 || city.longitude.abs() > 180) {
      throw const FormatException('Invalid prayer city coordinates');
    }
    final zone = _location(city);
    final local = tz.TZDateTime.from(instant, zone);
    final date = tz.TZDateTime(zone, local.year, local.month, local.day);
    final result = ad.PrayerTimes(
      coordinates: ad.Coordinates(city.latitude, city.longitude),
      date: date,
      calculationParameters: _parameters(method, asr),
    );
    DateTime convert(DateTime utc) => tz.TZDateTime.from(utc, zone);
    return PrayerSchedule(date, [
      PrayerEvent('Fajr', convert(result.fajr)),
      PrayerEvent('Sunrise', convert(result.sunrise), isObligatory: false),
      PrayerEvent('Dhuhr', convert(result.dhuhr)),
      PrayerEvent('Asr', convert(result.asr)),
      PrayerEvent('Maghrib', convert(result.maghrib)),
      PrayerEvent('Isha', convert(result.isha)),
    ]);
  }

  /// Sunrise is intentionally excluded as an obligatory prayer.
  PrayerEvent nextPrayer(
      PrayerCity city, DateTime instant, PrayerMethod method, AsrRule asr) {
    final today = forInstant(city, instant, method, asr);
    for (final event in today.events) {
      if (event.isObligatory && event.at.isAfter(instant)) return event;
    }
    final nextDay = tz.TZDateTime(
        _location(city), today.date.year, today.date.month, today.date.day + 1);
    return forInstant(city, nextDay, method, asr).events.first;
  }
}

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  final service = PrayerTimeService();
  String? cityId;
  PrayerMethod method = PrayerMethod.mwl;
  AsrRule asr = AsrRule.standard;
  bool loading = true;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await SafwaPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        final choice = p.getString('safwa_prayer_city');
        cityId = prayerCities.any((c) => c.id == choice) ? choice : null;
        method = PrayerMethod.values.firstWhere(
          (x) => x.name == p.getString('safwa_prayer_method'),
          orElse: () => PrayerMethod.mwl,
        );
        asr = AsrRule.values.firstWhere(
          (x) => x.name == p.getString('safwa_prayer_asr'),
          orElse: () => AsrRule.standard,
        );
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    try {
      final p = await SafwaPreferences.getInstance();
      if (cityId != null) await p.setString('safwa_prayer_city', cityId!);
      await p.setString('safwa_prayer_method', method.name);
      await p.setString('safwa_prayer_asr', asr.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save prayer settings locally.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF142547);
    const gold = Color(0xFFAD8744);
    PrayerCity? city;
    for (final option in prayerCities) {
      if (option.id == cityId) city = option;
    }
    PrayerSchedule? schedule;
    PrayerEvent? next;
    if (!loading && city != null) {
      try {
        schedule = service.forInstant(city, now, method, asr);
        next = service.nextPrayer(city, now, method, asr);
      } catch (_) {
        // Fail closed instead of displaying a fabricated prayer time.
      }
    }
    String clock(DateTime instant) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: instant.hour, minute: instant.minute),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times'), actions: [
        IconButton(
          tooltip: 'Refresh prayer times',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => now = DateTime.now()),
        ),
      ]),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(20), children: [
            const Text('SAFWA  /  SALAH',
              style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('Plan your day around prayer.',
              style: TextStyle(color: navy, fontSize: 28,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Offline calculations. Choose a city manually; '
              'Safwa never requests your GPS location.'),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: const Key('prayer_city'),
              initialValue: cityId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Choose a city', border: OutlineInputBorder()),
              items: prayerCities.map((c) => DropdownMenuItem(
                value: c.id, child: Text(c.name))).toList(),
              onChanged: (value) {
                setState(() { cityId = value; now = DateTime.now(); });
                save();
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<PrayerMethod>(
              initialValue: method, isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Calculation method', border: OutlineInputBorder()),
              items: PrayerMethod.values.map((m) => DropdownMenuItem(
                value: m, child: Text(m.label))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => method = value);
                save();
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AsrRule>(
              initialValue: asr, isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Asr calculation', border: OutlineInputBorder()),
              items: AsrRule.values.map((a) => DropdownMenuItem(
                value: a, child: Text(a.label))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => asr = value);
                save();
              },
            ),
            const SizedBox(height: 20),
            if (city == null)
              const Card(child: Padding(padding: EdgeInsets.all(20),
                child: Text('Select a city to see estimated prayer times. '
                  'No location is assumed.')))
            else if (schedule == null || next == null)
              const Card(child: Padding(padding: EdgeInsets.all(20),
                child: Text('Prayer-time calculation unavailable. '
                  'No unverified times will be displayed.')))
            else ...[
              Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city.name.toUpperCase(), style: const TextStyle(
                    color: gold, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text('Next prayer: ${next.name}',
                    style: const TextStyle(fontSize: 20, color: navy,
                      fontWeight: FontWeight.w700)),
                  Text(clock(next.at), style: const TextStyle(
                    color: navy, fontSize: 30, fontWeight: FontWeight.w800)),
                  Text('${city.zone}  •  ${schedule.date.year}-'
                    '${schedule.date.month.toString().padLeft(2, '0')}-'
                    '${schedule.date.day.toString().padLeft(2, '0')}'),
                ]))),
              const SizedBox(height: 10),
              ...schedule.events.map((event) => Card(child: ListTile(
                leading: Icon(event.isObligatory
                    ? Icons.access_time : Icons.wb_twilight_outlined,
                  color: event.isObligatory ? navy : gold),
                title: Text(event.name),
                subtitle: event.isObligatory ? null
                    : const Text('Sunrise is not an obligatory prayer'),
                trailing: Text(clock(event.at), style: const TextStyle(
                    color: navy, fontSize: 17, fontWeight: FontWeight.w700)),
              ))),
            ],
            const SizedBox(height: 20),
            const Text('Astronomical estimates, not an official local mosque '
              'timetable. Verify calculation method and times with local '
              'religious authorities. No GPS or notifications are enabled.',
              style: TextStyle(fontSize: 12, color: navy)),
          ]),
    );
  }
}
