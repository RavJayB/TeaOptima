// lib/screens/result_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';       // ← new
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/config_service.dart';
import 'main_screen.dart';

class ResultScreen extends StatefulWidget {
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Map<String, dynamic> payload;
  late List<dynamic> timeline;
  late List<dynamic> milestones;

  final List<FlSpot> spots = [];
  int tappedIdx = 0;
  double guideX = 0;

  String infoLine = '';
  List<String> factors = [];

  String place = 'Fetching…', temp = '--', hum = '--', rain = '--';

  bool _saving = false;
  bool _saved = false;

  final DateFormat _fmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _getWeather();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is Map<String, dynamic>) {
      payload    = args;
      timeline   = List.from(payload['timeline']   ?? []);
      milestones = List.from(payload['milestones'] ?? []);
      _buildSpots();
      _selectPoint(0);

      if (!_saved) {
        _saveSimulation().then((_) {
          if (mounted) setState(() => _saved = true);
        });
      }
    }
  }

  Future<void> _saveSimulation() async {
    setState(() => _saving = true);

    try {
      // 0️⃣ Grab the currently signed‐in user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // 1️⃣ Upload the image (if any)
      String? imgUrl;
      final base64Img = payload['image_base64'] as String?;
      if (base64Img != null && base64Img.isNotEmpty) {
        final bytes = base64Decode(base64Img);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance
            .ref()
            .child('simulations/${user.uid}/$ts.jpg');
        await ref.putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imgUrl = await ref.getDownloadURL();
      }

      // 2️⃣ Build your Firestore doc, now including userId
      final doc = {
        'userId'           : user.uid,  
        'created_at'       : FieldValue.serverTimestamp(),
        'leaf_age'         : payload['leaf_age'] ?? payload['leafAge'],
        'starting_quality' : payload['startingQuality'],
        'location'         : place,
        'weather'          : {'temp': temp, 'hum': hum, 'rain': rain},
        'timeline'         : timeline,
        'milestones'       : milestones,
        'image_url'        : imgUrl,
      };

      // 3️⃣ Write it
      await FirebaseFirestore.instance
          .collection('simulations')
          .add(doc);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('⚠️ Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _buildSpots() {
    spots.clear();
    for (final d in timeline) {
      spots.add(FlSpot(
        (d['day']   as num).toDouble(),
        (d['pred_q'] as num).toDouble(),
      ));
    }
  }

  String _dayToDate(int dayNumber) {
    final d = DateTime.now().add(Duration(days: dayNumber));
    String suf(int x) {
      if (x >= 11 && x <= 13) return 'th';
      switch (x % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
      }
    }
    return '${d.day}${suf(d.day)} ${_fmt.format(d)}';
  }

  void _selectPoint(int idx) {
    tappedIdx = idx;
    final t = timeline[idx];
    guideX = (t['day'] as num).toDouble();
    final dateStr = _dayToDate(t['day'] as int);

    infoLine =
      '$dateStr · ${t['tier']}  '
      '🌡️ ${(t['temp'] as num).toStringAsFixed(1)}°C  '
      '💧 ${t['hum']}%  ☔ ${t['rain']} mm';

    factors = t['explanation']
      .toString()
      .split('\n')
      .skip(2)
      .map((l) => l
        .replaceAll(RegExp(r'[🌿📊•→]'), '')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim())
      .where((l) => l.isNotEmpty)
      .toList();
  }

  Future<void> _getWeather() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();

      final key = ConfigService.openWeatherApiKey;
      final w = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&appid=$key&units=metric'
      ));
      final g = await http.get(Uri.parse(
        'https://api.openweathermap.org/geo/1.0/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&limit=1&appid=$key'
      ));

      if (w.statusCode == 200 && g.statusCode == 200) {
        final jw = jsonDecode(w.body);
        final jg = jsonDecode(g.body) as List<dynamic>;
        setState(() {
          temp  = "${(jw['main']['temp']   as num).toStringAsFixed(1)}°C";
          hum   = "${ jw['main']['humidity']}%";
          rain  = jw['rain']?['1h'] != null
                    ? "${jw['rain']['1h']} mm"
                    : "0 mm";
          place = jg.isNotEmpty ? (jg[0]['name'] ?? 'Unknown') : 'Unknown';
        });
      }
    } catch (_) {
      // silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    // stringify your incoming payload fields
    final leafAgeRaw   = payload['leaf_age'] ?? payload['leafAge']   ?? '--';
    final startQualRaw = payload['startingQuality'] ?? payload['quality'] ?? '--';
    final leafAge   = leafAgeRaw.toString();
    final startQual = startQualRaw.toString();

    // compute lastTier, lastDay, maxDay
    final tierRaw = timeline.isNotEmpty ? timeline.last['tier'] : '--';
    final dayRaw  = timeline.isNotEmpty ? timeline.last['day']  : 0;
    final maxRaw  = timeline.isNotEmpty ? timeline.last['day']  : 15;

    final lastTier = tierRaw.toString();
    final lastDay  = (dayRaw  is num) ? dayRaw.toInt() : int.tryParse(dayRaw.toString()) ?? 0;
    final maxDay   = (maxRaw  is num) ? maxRaw.toInt() : int.tryParse(maxRaw.toString()) ?? 15;

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Results')),
      body: timeline.isEmpty
        ? const Center(child: Text('No timeline data'))
        : Stack(
            children: [
              _buildBody(leafAge, startQual, lastTier, lastDay, maxDay),
              if (_saving)
                const Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
    );
  }

  Widget _buildBody(String leafAge, String startQual, String lastTier, int lastDay, int maxDay) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // — header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.location_pin),
              const SizedBox(width: 4),
              Text(place),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Leaf Age: $leafAge days'),
              Text('Starting Quality: $startQual'),
            ]),
          ],
        ),
        const Divider(height: 28),

        // — chart
        const Text('15-Day Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 240,
          child: LineChart(LineChartData(
            minX: 1, maxX: maxDay.toDouble(), minY: 1, maxY: 4,
            borderData: FlBorderData(show: true),
            gridData: FlGridData(show: true),
            extraLinesData: ExtraLinesData(verticalLines: [
              VerticalLine(
                x: guideX,
                color: Colors.deepOrange.withOpacity(.6),
                strokeWidth: 2,
                dashArray: [4, 4],
              ),
            ]),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, interval: 1,
                getTitlesWidget: (v,_) => Text(v.toInt().toString()),
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v,_) => Text('T${5 - v.toInt()}'),
              )),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchCallback: (e, resp) {
                if (resp?.lineBarSpots?.isNotEmpty ?? false) {
                  final idx = resp!.lineBarSpots!.first.x.toInt() - 1;
                  if (idx >= 0 && idx < timeline.length) {
                    setState(() => _selectPoint(idx));
                  }
                }
              },
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 3,
                color: Colors.orange,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, idx) {
                    final sel = idx == tappedIdx;
                    return FlDotCirclePainter(
                      radius: sel ? 6 : 3,
                      color: sel ? Colors.deepOrange : Colors.orange,
                    );
                  },
                ),
              ),
            ],
          )),
        ),

        const SizedBox(height: 8),
        Text('🧠 Degradation will Reach: $lastTier on ${_dayToDate(lastDay)}',
             style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 16),

        // — Key Factors
        Card(
          color: Colors.green.shade50,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(infoLine, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text('Key Factors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(f)),
                ]),
              )),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        // — Harvest Suggestions
        Card(
          color: Colors.green.shade50,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Harvest Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (milestones.isEmpty)
                  const Text(
                    'Current tea batch is already reach to T4(Poor). Therefore not good enough to process.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  ...milestones.map(_suggestionRow),
              ],
            ),
          ),
        ),

        const Divider(height: 32),

        // — Footer Weather
        const Text('Today’s Weather', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _weatherTile(Icons.thermostat, Colors.redAccent, 'Temp', temp),
          _weatherTile(Icons.water_drop, Colors.blue,      'Humidity', hum),
          _weatherTile(Icons.cloud,      Colors.grey,       'Rain',     rain),
        ]),

        const SizedBox(height: 28),
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
              builder: (_) => const MainScreen(startingIndex: 1),
              ),
            ),
            child: const Text('Back to Capture'),
          ),
        ),
      ]),
    );
  }

  Widget _suggestionRow(dynamic m) {
  var rec = (m['recommendation'] ?? '').toString().replaceAll('**', '');
  final match = RegExp(r'day (-?\d+)').firstMatch(rec.toLowerCase());
  if (match != null) {
    final d = int.parse(match.group(1)!);
    if (d <= 0) {
      rec = rec.replaceFirst(RegExp(r'before day -?\d+', caseSensitive: false), 'within today');
    } else {
      rec = rec.replaceFirst(RegExp(r'day \d+', caseSensitive: false), _dayToDate(d));
    }
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(rec, style: const TextStyle(color: Colors.indigo)),
  );
}


  Widget _weatherTile(IconData icon, Color c, String lbl, String val) =>
      Column(children: [
        Icon(icon, color: c),
        const SizedBox(height: 4),
        Text('$lbl\n$val', textAlign: TextAlign.center),
      ]);
}
