// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/config_service.dart';
import 'main_screen.dart';

// ────────────────────────────────────────────────────────────
// A little singleton to cache last fetch + 15 min rule
// ────────────────────────────────────────────────────────────
class WeatherCache {
  static DateTime? _lastFetch;
  static String   location = 'Fetching…';
  static double   temp     = 0;
  static double   hum      = 0;
  static double   rain     = 0;

  static Future<void> load({bool force = false}) async {
    // if we fetched recently (<15m) and not forced, just return
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 15)) {
      return;
    }

    try {
      // 1) Location perm
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        location = 'Location disabled';
        return;
      }

      // 2) Get coords
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final lat = pos.latitude, lon = pos.longitude;
      final apiKey = ConfigService.openWeatherApiKey;

      // 3) Reverse geocode
      final geoUri = Uri.https('api.openweathermap.org', '/geo/1.0/reverse', {
        'lat': '$lat',
        'lon': '$lon',
        'limit': '1',
        'appid': apiKey,
      });
      final geoRes = await http.get(geoUri);
      if (geoRes.statusCode == 200) {
        final list = jsonDecode(geoRes.body) as List<dynamic>;
        if (list.isNotEmpty) {
          location = list[0]['name'] as String? ?? 'Unknown';
        }
      }

      // 4) Fetch weather
      final wUri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
        'lat': '$lat',
        'lon': '$lon',
        'units': 'metric',
        'appid': apiKey,
      });
      final wRes  = await http.get(wUri);
      final wData = jsonDecode(wRes.body);
      temp = (wData['main']['temp'] as num).toDouble();
      hum  = (wData['main']['humidity'] as num).toDouble();
      rain = (wData['rain']?['1h'] as num?)?.toDouble() ?? 0;

      // 5) Stamp fetch time
      _lastFetch = DateTime.now();
    } catch (_) {
      // swallow
    }
  }
}

// ────────────────────────────────────────────────────────────
// HomeScreen now simply drives from that cache
// ────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // carousel
  final _headerController = PageController();
  late Timer _carouselTimer;
  final List<String> _headerImages = [
    'assets/onboard4.webp',
    'assets/onboard9.jpg',
    'assets/onboard7.jpg',
    'assets/homesc4.jpg',
  ];

  // greeting + user
  String _greeting = '';
  String get _userName {
    final raw = FirebaseAuth.instance.currentUser?.displayName ?? 'Farmer';
    return raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _setupGreeting();
    _startCarousel();
    // THIS will only actually fetch if >15m or never fetched
    WeatherCache.load().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _headerController.dispose();
    super.dispose();
  }

  void _setupGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) _greeting = 'Good Morning';
    else if (h < 17) _greeting = 'Good Afternoon';
    else _greeting = 'Good Evening';
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      var next = (_headerController.page ?? 0).toInt() + 1;
      if (next >= _headerImages.length) next = 0;
      _headerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // pick main metric
    final metrics = {
      'Temperature': WeatherCache.temp,
      'Humidity'   : WeatherCache.hum,
      'Rainfall'   : WeatherCache.rain,
    };
    final mainKey = metrics.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final others = metrics.keys.where((k) => k != mainKey).toList();

    Color green900 = Colors.green.shade900;
    Color green700 = Colors.green.shade700;
    Color grey700  = Colors.grey.shade700;

    Widget tile(String key, double v, bool big) {
      IconData icon;
      switch (key) {
        case 'Temperature': icon = Icons.thermostat; break;
        case 'Humidity':    icon = Icons.water_drop;  break;
        default:            icon = Icons.cloud;
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: big ? 45 : 28, color: big ? Colors.orange : grey700),
          const SizedBox(height: 4),
          Text(
            big
                ? '${v.toStringAsFixed(1)}°'
                : key == 'Rainfall'
                    ? '${v.toStringAsFixed(1)} mm'
                    : key == 'Humidity'
                        ? '${v.toStringAsFixed(0)} %'
                        : '${v.toStringAsFixed(1)}°',
            style: TextStyle(
              fontSize: big ? 36 : 14,
              fontWeight: big ? FontWeight.bold : FontWeight.normal,
              color: big ? green900 : grey700,
            ),
          ),
          if (big) ...[
            const SizedBox(height: 3),
            Text(key, style: TextStyle(fontSize: 18, color: green700)),
          ]
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EE),
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: () async {
          await WeatherCache.load(force: true);
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── header carousel ────────────────────────────
              SizedBox(
                height: 260,
                child: PageView.builder(
                  controller: _headerController,
                  itemCount: _headerImages.length,
                  itemBuilder: (_, i) => Image.asset(
                    _headerImages[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── greeting + name ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_greeting $_userName!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: green900),
                ),
              ),

              const SizedBox(height: 16),

              // ─── weather card ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFFFEFDF5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // location
                        Row(
                          children: [
                            const Icon(Icons.location_pin,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                WeatherCache.location,
                                style: TextStyle(fontSize: 16, color: grey700),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // metrics row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            tile(others[0], metrics[others[0]]!, false),
                            tile(mainKey, metrics[mainKey]!, true),
                            tile(others[1], metrics[others[1]]!, false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 27),

              // ─── buttons ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green900,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const MainScreen(startingIndex: 1),
                        ),
                      ),
                      child: const Text('New Prediction',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const MainScreen(startingIndex: 2),
                        ),
                      ),
                      child: const Text('History',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
