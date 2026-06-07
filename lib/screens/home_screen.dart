// lib/screens/home_screen.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../theme/tea_theme.dart';
import '../widgets/price_ticker_banner.dart';
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

      // 3) Reverse geocode via backend
      final loc = await ApiService.getLocation(lat: lat, lon: lon);
      location = (loc['name'] as String?) ?? 'Unknown';

      // 4) Current weather via backend
      final w = await ApiService.getCurrentWeather(lat: lat, lon: lon);
      temp = (w['temp'] as num).toDouble();
      hum  = (w['hum']  as num).toDouble();
      rain = (w['rain'] as num).toDouble();

      // 5) Stamp fetch time
      _lastFetch = DateTime.now();
    } catch (e, st) {
      debugPrint('WeatherCache.load failed: $e\n$st');
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
  int _currentPage = 0;
  final List<String> _headerImages = [
    'assets/onboard4.webp',
    'assets/onboard9.jpg',
    'assets/onboard7.jpg',
    'assets/homesc4.jpg',
  ];

  // user
  String get _userName {
    final raw = FirebaseAuth.instance.currentUser?.displayName ?? 'Farmer';
    return raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _startCarousel();
    // THIS will only actually fetch if >15m or never fetched
    WeatherCache.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _headerController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      extendBody: true,
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: RefreshIndicator(
          color: TeaTheme.primary,
          onRefresh: () async {
            await WeatherCache.load(force: true);
            if (mounted) setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroCarousel(),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: PriceTickerBanner(),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _weatherCard(),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _actionSection(),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero carousel with overlay + page dots ────────────────────────────────
  Widget _heroCarousel() {
    final l = AppLocalizations.of(context);
    IconData greetIcon;
    final String greeting;
    final h = DateTime.now().hour;
    if (h < 12) {
      greetIcon = Icons.wb_sunny_rounded;
      greeting = l.homeGoodMorning;
    } else if (h < 17) {
      greetIcon = Icons.wb_twilight_rounded;
      greeting = l.homeGoodAfternoon;
    } else {
      greetIcon = Icons.nights_stay_rounded;
      greeting = l.homeGoodEvening;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // images
            PageView.builder(
              controller: _headerController,
              itemCount: _headerImages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) => Image.asset(
                _headerImages[i],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // legibility scrim
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            // top brand row
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.eco_rounded,
                                color: Colors.white, size: 15),
                            SizedBox(width: 5),
                            Text(
                              'TEAOPTIMA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // greeting overlay
            Positioned(
              left: 22,
              right: 22,
              bottom: 34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(greetIcon,
                          color: Colors.white.withOpacity(0.95), size: 17),
                      const SizedBox(width: 6),
                      Text(
                        greeting,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l.homeHi(_userName)} 🌱',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.homeWelcome,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // page dots
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_headerImages.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weather card ──────────────────────────────────────────────────────────
  Widget _weatherCard() {
    final l = AppLocalizations.of(context);
    final loc = WeatherCache.location;
    final hasData = loc != 'Fetching…' && loc != 'Location disabled';
    return Container(
      decoration: TeaTheme.card(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: TeaTheme.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: TeaTheme.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeCurrentConditions,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TeaTheme.deep,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _weatherTile(Icons.thermostat_rounded, l.homeTemp,
                  hasData ? '${WeatherCache.temp.toStringAsFixed(1)}°C' : '–',
                  const Color(0xFFD9534F)),
              const SizedBox(width: 8),
              _weatherTile(Icons.water_drop_rounded, l.homeHumidity,
                  hasData ? '${WeatherCache.hum.toStringAsFixed(0)}%' : '–',
                  const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _weatherTile(Icons.umbrella_rounded, l.homeRain,
                  hasData ? '${WeatherCache.rain.toStringAsFixed(1)} mm' : '–',
                  const Color(0xFF6B7280)),
            ],
          ),
          if (!hasData) ...[
            const SizedBox(height: 10),
            Text(
              loc == 'Location disabled'
                  ? l.homeEnableLocation
                  : l.homeFetching,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weatherTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: TeaTheme.deep,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action section ────────────────────────────────────────────────────────
  Widget _actionSection() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            l.homeQuickActions,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TeaTheme.deep.withOpacity(0.7),
            ),
          ),
        ),
        // Primary CTA
        _primaryAction(),
        const SizedBox(height: 12),
        // Secondary
        _secondaryAction(),
      ],
    );
  }

  Widget _primaryAction() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainScreen(startingIndex: 1),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
            ),
            boxShadow: [
              BoxShadow(
                color: TeaTheme.primary.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -16,
                child: Icon(Icons.eco_rounded,
                    size: 110, color: Colors.white.withOpacity(0.08)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.30)),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).homeNewPrediction,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context).homeNewPredictionSub,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryAction() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainScreen(startingIndex: 2),
          ),
        ),
        child: Container(
          decoration: TeaTheme.card().copyWith(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: TeaTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: TeaTheme.primary, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).homePredictionHistory,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: TeaTheme.deep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).homeHistorySub,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
