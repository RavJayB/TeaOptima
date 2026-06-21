// lib/screens/result_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';       // ← new
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/pdf_report_service.dart';
import '../theme/tea_theme.dart';
import '../services/pricing_service.dart';
import '../services/recommendation_engine.dart';
import '../services/locale_controller.dart';
import 'main_screen.dart';
import 'home_screen.dart' show WeatherCache;

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
  // Structured SHAP factors for the selected day: {key, value, contribution}.
  // Positive contribution = protective; negative = speeds degradation.
  List<Map<String, dynamic>> factorData = [];

  String place = 'Fetching…', temp = '--', hum = '--', rain = '--';

  bool _saving = false;
  bool _saved = false;

  // Economic impact state — see PricingService for storage details
  Map<String, double> _prices = Map.from(PricingService.defaultPrices);
  double _batchKg = PricingService.defaultBatchKg;

  // month + year only — the ordinal day is prefixed separately in _dayToDate
  final DateFormat _fmt = DateFormat('MMM yyyy');
  final NumberFormat _money =
      NumberFormat.currency(locale: 'en_LK', symbol: 'Rs ', decimalDigits: 0);

  late final Future<void> _weatherReady;

  @override
  void initState() {
    super.initState();
    _applyWeatherFromCache();           // instant: reuse the fetch Home already did
    _weatherReady = _refreshWeather();  // refresh only if stale (15-min rule)
    _loadPricing();
  }

  /// Copy the latest weather from the shared cache into local display fields.
  void _applyWeatherFromCache() {
    final loc = WeatherCache.location;
    if (loc.isNotEmpty && loc != 'Fetching…' && loc != 'Location disabled') {
      place = loc;
      temp = '${WeatherCache.temp.toStringAsFixed(1)}°C';
      hum = '${WeatherCache.hum.toStringAsFixed(0)}%';
      rain = '${WeatherCache.rain.toStringAsFixed(1)} mm';
    } else if (loc.isNotEmpty && loc != 'Fetching…') {
      place = loc; // e.g. "Location disabled" — surface it, leave metrics as-is
    }
  }

  /// Refresh via the shared cache (no duplicate geolocation unless stale).
  Future<void> _refreshWeather() async {
    await WeatherCache.load();
    if (!mounted) return;
    setState(_applyWeatherFromCache);
  }

  Future<void> _loadPricing() async {
    final prices = await PricingService.loadPrices();
    final batch = await PricingService.loadBatchKg();
    if (!mounted) return;
    setState(() {
      _prices = prices;
      _batchKg = batch;
    });
  }

  bool _exporting = false;

  Future<void> _sharePdf() async {
    if (_exporting || timeline.isEmpty) return;
    final code = await _pickExportLanguage();
    if (code == null) return; // user dismissed the picker
    final l = lookupAppLocalizations(Locale(code));
    setState(() => _exporting = true);
    try {
      final leafAgeRaw = payload['leaf_age'] ?? payload['leafAge'] ?? 1;
      final leafAge = (leafAgeRaw is num)
          ? leafAgeRaw.toInt()
          : int.tryParse(leafAgeRaw.toString()) ?? 1;
      final startQual =
          (payload['startingQuality'] ?? payload['quality'] ?? '--')
              .toString();
      final terminal = timeline.last['tier'].toString();

      final bytes = await PdfReportService.generate(
        l: l,
        timeline: timeline,
        milestones: milestones,
        startingQuality: startQual,
        terminalTier: terminal,
        leafAge: leafAge,
        prices: _prices,
        batchKg: _batchKg,
        place: place,
        currentTemp: temp,
        currentHum: hum,
        currentRain: rain,
        imageBase64: payload['image_base64'] as String?,
      );

      final filename =
          'teaoptima_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).resPdfFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // Ask which language the exported PDF should be rendered in. Independent of
  // the in-app language so growers can share an English copy with the factory
  // while reading the app in Sinhala/Tamil (or vice-versa).
  Future<String?> _pickExportLanguage() {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.tea.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.tea.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.tea.surface,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.translate_rounded,
                          color: context.tea.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.pdfExportLanguage,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.tea.ink,
                            ),
                          ),
                          Text(
                            l.pdfChooseLanguage,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tea.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...LocaleController.supported.entries.map((e) {
                  final isCurrent = e.key == LocaleController.currentCode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx, e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.tea.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent ? context.tea.accent : context.tea.border,
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.tea.ink,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                isCurrent
                                    ? Icons.check_circle_rounded
                                    : Icons.chevron_right_rounded,
                                color: isCurrent
                                    ? _teaPrimary
                                    : Colors.grey.shade400,
                                size: isCurrent ? 20 : 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
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
      if (timeline.isNotEmpty) _selectPoint(0);

      if (!_saved) {
        _saved = true; // guard immediately against re-entry
        // Save only once weather is ready, so history never records "Fetching…".
        _weatherReady.then((_) => _saveSimulation());
      }
    }
  }

  Future<void> _saveSimulation() async {
    setState(() => _saving = true);

    try {
      // 0️⃣ Grab the currently signed‐in user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // 1️⃣ Upload the image (if any). Storage requires Blaze plan — if it
      //    fails (e.g. 402 on Spark plan), skip the image and still save the
      //    rest of the simulation to Firestore.
      String? imgUrl;
      final base64Img = payload['image_base64'] as String?;
      if (base64Img != null && base64Img.isNotEmpty) {
        try {
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
        } catch (_) {
          imgUrl = null;
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).resSaveFailed('$e'))));
      }
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
    if (timeline.isEmpty || idx >= timeline.length) return;
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

    final rawFactors = t['factors'];
    factorData = (rawFactors is List)
        ? rawFactors
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
      backgroundColor: context.tea.bg,
      appBar: AppBar(
        backgroundColor: context.tea.bg,
        foregroundColor: context.tea.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l.resTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          if (timeline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _exporting ? null : _sharePdf,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E3F), Color(0xFF2E7D5B)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E3F).withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_exporting)
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.ios_share_rounded,
                              color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          l.resReport,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: timeline.isEmpty
          ? Center(child: Text(l.resNoTimeline))
          : Stack(
              children: [
                _buildBody(leafAge, startQual, lastTier, lastDay, maxDay),
                if (_saving)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFFE5EFE9),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1B5E3F)),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: timeline.isEmpty ? null : _buildBottomCta(),
    );
  }

  Widget _buildBody(String leafAge, String startQual, String lastTier,
      int lastDay, int maxDay) {
    return Container(
      decoration: TeaTheme.gradientOf(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact stat header
            _buildHeaderCard(leafAge, startQual),
            const SizedBox(height: 14),

            // ── HERO: quality trajectory chart (chart at the top, per request)
            _buildJourneyCard(startQual, lastTier, lastDay, maxDay),
            const SizedBox(height: 14),

            // ── Urgency callout
            _buildUrgencyCard(),
            const SizedBox(height: 14),

            // ── Economic impact
            _buildImpactCard(),
            const SizedBox(height: 14),

            // ── AI-driven expert insights (rule-based agronomy engine)
            _buildInsightsCard(),
            const SizedBox(height: 14),

            // ── Selected-day deep dive (drives off chart selection)
            _buildSelectedDayCard(),
            const SizedBox(height: 14),

            // ── Action plan
            _buildSuggestionsCard(),
            const SizedBox(height: 14),

            // ── Current field conditions
            _buildWeatherCard(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Tea palette helpers (single source of truth for greens + tier colours)
  // ───────────────────────────────────────────────────────────────────────
  static const _teaDeep = Color(0xFF0F3D2E);
  static const _teaPrimary = Color(0xFF1B5E3F);
  static const _teaMid = Color(0xFF2E7D5B);
  static const _teaBright = Color(0xFF22C55E);
  static const _teaGold = Color(0xFFD4A82C);

  Color _tierColor(String tier) {
    final m = RegExp(r'T([1-4])').firstMatch(tier);
    if (m == null) return Colors.grey;
    switch (m.group(1)) {
      case '1':
        return const Color(0xFF0F4D2E);
      case '2':
        return const Color(0xFF3E7D4E);
      case '3':
        return const Color(0xFFB8843A);
      case '4':
        return const Color(0xFFA04823);
      default:
        return Colors.grey;
    }
  }

  String _tierShort(String tier) =>
      RegExp(r'T[1-4]').firstMatch(tier)?.group(0) ?? tier;

  BoxDecoration _surfaceCard() => TeaTheme.cardOf(context);

  Widget _sectionHeading(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.tea.surface,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: context.tea.accent, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: context.tea.ink,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Stat header card ────────────────────────────────────────────────────
  Widget _buildHeaderCard(String leafAge, String startQual) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          children: [
            _headerStat(
              icon: Icons.location_on_rounded,
              iconColor: _teaPrimary,
              label: l.resLocation,
              value: place,
            ),
            _verticalDivider(),
            _headerStat(
              icon: Icons.energy_savings_leaf_rounded,
              iconColor: _teaMid,
              label: l.resLeafAgeLabel,
              value: '$leafAge ${l.histDayShort}',
            ),
            _verticalDivider(),
            _headerStat(
              icon: Icons.workspace_premium_rounded,
              iconColor: _tierColor(startQual),
              label: l.resStarting,
              value: _tierShort(startQual),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: context.tea.faint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: context.tea.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: context.tea.border,
      );

  // ── Quality trajectory (chart + tier journey) ──────────────────────────
  Widget _buildJourneyCard(
      String startQual, String lastTier, int lastDay, int maxDay) {
    final l = AppLocalizations.of(context);
    final startShort = _tierShort(startQual);
    final endShort = _tierShort(lastTier);
    final dropped = startShort != endShort;

    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
              Icons.show_chart_rounded,
              l.resQualityTrajectory,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teaPrimary, _teaMid],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.resDaysCount(lastDay),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Tier hero transition
            Row(
              children: [
                _journeyBadge(startShort),
                const SizedBox(width: 10),
                Icon(
                  dropped
                      ? Icons.trending_down_rounded
                      : Icons.horizontal_rule_rounded,
                  color: dropped ? const Color(0xFFB8843A) : _teaMid,
                  size: 20,
                ),
                const SizedBox(width: 10),
                _journeyBadge(endShort),
                const Spacer(),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.tea.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded,
                            size: 13, color: context.tea.accent),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            l.resByDate(DateFormat('d MMM').format(
                                DateTime.now().add(Duration(days: lastDay)))),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.tea.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Chart
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: maxDay.toDouble(),
                  minY: 1,
                  maxY: 4,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.tea.border,
                      strokeWidth: 1,
                      dashArray: [4, 6],
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: guideX,
                        color: _teaGold.withOpacity(0.75),
                        strokeWidth: 1.5,
                        dashArray: const [4, 4],
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            v.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.tea.sub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final tier = 'T${5 - v.toInt()}';
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              tier,
                              style: TextStyle(
                                fontSize: 11,
                                color: _tierColor(tier),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _teaDeep,
                      tooltipRoundedRadius: 10,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              l.resChartTooltip(
                                  spot.x.toInt(), 'T${5 - spot.y.toInt()}'),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                          .toList(),
                    ),
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
                      isCurved: true,
                      curveSmoothness: 0.18,
                      barWidth: 3.5,
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          _teaPrimary,
                          Color(0xFF3E7D4E),
                          Color(0xFFB8843A),
                        ],
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _teaPrimary.withOpacity(0.18),
                            _teaPrimary.withOpacity(0.02),
                          ],
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) {
                          final sel = idx == tappedIdx;
                          return FlDotCirclePainter(
                            radius: sel ? 5.5 : 3,
                            color: sel ? _teaGold : _teaPrimary,
                            strokeWidth: sel ? 3 : 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 12, color: context.tea.faint),
                  const SizedBox(width: 4),
                  Text(
                    l.resTapPoint,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.tea.sub,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journeyBadge(String tier) {
    final c = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c, c.withOpacity(0.82)],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.32),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        tier,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Selected day deep dive ──────────────────────────────────────────────
  Widget _buildSelectedDayCard() {
    if (timeline.isEmpty || tappedIdx >= timeline.length) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = timeline[tappedIdx];
    final tierLabel = (t['tier'] ?? '').toString();
    final tierShort = _tierShort(tierLabel);
    final tierC = _tierColor(tierShort);
    final dateStr = _dayToDate(t['day'] as int);
    final tempVal = (t['temp'] as num).toDouble();
    final humVal = (t['hum'] as num).toDouble();
    final rainVal = (t['rain'] as num).toDouble();

    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
              Icons.calendar_today_rounded,
              l.resDayDetails,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tierC.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tierShort,
                  style: TextStyle(
                    color: tierC,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.tea.ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniWeatherChip(Icons.thermostat_rounded,
                    '${tempVal.toStringAsFixed(1)}°C',
                    const Color(0xFFD9534F)),
                _miniWeatherChip(Icons.water_drop_rounded,
                    '${humVal.toStringAsFixed(0)}%',
                    const Color(0xFF3B82F6)),
                _miniWeatherChip(Icons.umbrella_rounded,
                    '${rainVal.toStringAsFixed(1)} mm',
                    const Color(0xFF6B7280)),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: context.tea.border),
            const SizedBox(height: 12),
            Text(
              l.resWhatDrives,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: context.tea.accent,
              ),
            ),
            const SizedBox(height: 10),
            if (factorData.isNotEmpty)
              ..._buildContributionBars(l)
            else if (factors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l.resNoDriver,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tea.sub,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...factors.map(_buildFactorRow),
          ],
        ),
      ),
    );
  }

  Widget _miniWeatherChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HSLColor.fromColor(color)
                  .withLightness(
                      (HSLColor.fromColor(color).lightness * 0.7)
                          .clamp(0.0, 1.0))
                  .toColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String factor) {
    final lower = factor.toLowerCase();
    final isAccel =
        lower.contains('speeds up') || lower.contains('accelerat');
    final isProtect =
        lower.contains('slows down') || lower.contains('protect');

    final color = isAccel
        ? const Color(0xFFB8843A)
        : (isProtect ? _teaPrimary : Colors.grey.shade600);
    final icon = isAccel
        ? Icons.trending_up_rounded
        : (isProtect
            ? Icons.shield_rounded
            : Icons.adjust_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              factor,
              style: TextStyle(
                fontSize: 13,
                color: context.tea.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SHAP contribution bars (full-forest, structured from backend) ────────
  List<Widget> _buildContributionBars(AppLocalizations l) {
    final maxAbs = factorData
        .fold<double>(0.0, (m, f) {
          final c = (f['contribution'] as num?)?.toDouble().abs() ?? 0.0;
          return c > m ? c : m;
        })
        .clamp(1e-6, double.infinity);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _legendDot(_teaPrimary, l.factorProtects),
            const SizedBox(width: 16),
            _legendDot(const Color(0xFFB8843A), l.factorDegrades),
          ],
        ),
      ),
      ...factorData.map((f) => _buildContributionBar(l, f, maxAbs)),
    ];
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: context.tea.sub,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContributionBar(
      AppLocalizations l, Map<String, dynamic> f, double maxAbs) {
    final key = (f['key'] ?? '').toString();
    final contribution = (f['contribution'] as num?)?.toDouble() ?? 0.0;
    final value = (f['value'] as num?)?.toDouble();
    final degrading = contribution < 0;
    final color = degrading ? const Color(0xFFB8843A) : _teaPrimary;
    final frac = (contribution.abs() / maxAbs).clamp(0.0, 1.0);
    final String valStr;
    if (value == null) {
      valStr = '';
    } else if (key == 'day_quality') {
      // day_quality is the internal score (4=T1 … 1=T4) — show the tier.
      valStr = 'T${5 - value.round().clamp(1, 4)}';
    } else if (value == value.roundToDouble()) {
      valStr = value.toStringAsFixed(0);
    } else {
      valStr = value.toStringAsFixed(1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                degrading
                    ? Icons.trending_down_rounded
                    : Icons.shield_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _factorLabel(l, key),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.tea.ink,
                  ),
                ),
              ),
              if (valStr.isNotEmpty)
                Text(
                  valStr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.tea.sub,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: context.tea.surface),
                FractionallySizedBox(
                  widthFactor: frac == 0 ? 0.012 : frac,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _factorLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'day_temp':
        return l.factorDayTemp;
      case 'day_hum':
        return l.factorDayHum;
      case 'day_rain':
        return l.factorDayRain;
      case 'day_quality':
        return l.factorDayQuality;
      case 'day_age':
        return l.factorDayAge;
      case 'stress_score':
        return l.factorStressScore;
      case 'heat_index':
        return l.factorHeatIndex;
      case 'temp_hum_ratio':
        return l.factorTempHumRatio;
      default:
        return key.replaceAll('_', ' ');
    }
  }

  // ── Harvest action plan ─────────────────────────────────────────────────
  Widget _buildSuggestionsCard() {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
                Icons.checklist_rounded, l.resActionPlan),
            const SizedBox(height: 14),
            if (milestones.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFB91C1C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.resT4NotSuitable,
                        style: TextStyle(
                          color: const Color(0xFFB91C1C),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(milestones.length, (i) {
                return _buildMilestoneStep(
                    milestones[i], i == milestones.length - 1);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneStep(dynamic m, bool isLast) {
    final l = AppLocalizations.of(context);
    var rec = (m['recommendation'] ?? '').toString().replaceAll('**', '');
    String dateStr = '';
    String tierKeep = '';

    final dayMatch = RegExp(r'day (-?\d+)').firstMatch(rec.toLowerCase());
    if (dayMatch != null) {
      final d = int.parse(dayMatch.group(1)!);
      dateStr = d <= 0 ? l.resToday : _dayToDate(d);
    }
    final tierMatch = RegExp(r'T[1-4]').firstMatch(rec);
    if (tierMatch != null) tierKeep = tierMatch.group(0)!;

    final c = _tierColor(tierKeep);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c, c.withOpacity(0.78)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: c.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  tierKeep.isEmpty ? '—' : tierKeep,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tierKeep.isEmpty
                        ? l.resKeepGrade
                        : l.resLockGrade(tierKeep),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.tea.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 13, color: context.tea.sub),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          dateStr.isEmpty
                              ? rec
                              : l.resHarvestBefore(dateStr),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.tea.sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Current field conditions ────────────────────────────────────────────
  Widget _buildWeatherCard() {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
              Icons.cloud_rounded,
              l.resFieldConditions,
              trailing: (place != 'Fetching…' && place != '--')
                  ? Flexible(
                      child: Text(
                        place,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.tea.sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _weatherStatCard(Icons.thermostat_rounded,
                    l.resTemperature, temp, const Color(0xFFD9534F)),
                const SizedBox(width: 8),
                _weatherStatCard(Icons.water_drop_rounded, l.homeHumidity,
                    hum, const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _weatherStatCard(Icons.umbrella_rounded, l.resRainfall, rain,
                    const Color(0xFF6B7280)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherStatCard(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: context.tea.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: context.tea.sub,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI insights (rule-based expert system) ─────────────────────────────
  Widget _buildInsightsCard() {
    final l = AppLocalizations.of(context);
    final leafAgeRaw = payload['leaf_age'] ?? payload['leafAge'] ?? 1;
    final leafAge = (leafAgeRaw is num)
        ? leafAgeRaw.toInt()
        : int.tryParse(leafAgeRaw.toString()) ?? 1;
    final startQual =
        (payload['startingQuality'] ?? payload['quality'] ?? '').toString();

    final recs = RecommendationEngine.generate(
      l: l,
      timeline: timeline,
      milestones: milestones,
      startingQuality: startQual,
      leafAge: leafAge,
      prices: _prices,
      batchKg: _batchKg,
    );

    if (recs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: _surfaceCard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
              Icons.auto_awesome_rounded,
              l.resAiInsights,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teaPrimary, _teaMid],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _teaPrimary.withOpacity(0.32),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      l.resInsightCount(recs.length),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color: context.tea.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.tea.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 13, color: context.tea.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.resInsightsBlurb,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.tea.accent,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(recs.length, (i) {
              return _buildInsightRow(recs[i], i == recs.length - 1);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(Recommendation r, bool isLast) {
    final l = AppLocalizations.of(context);
    final priorityColor = switch (r.priority) {
      RecPriority.high => const Color(0xFFD9534F),
      RecPriority.medium => const Color(0xFFD4A82C),
      RecPriority.low => _teaMid,
    };
    final priorityLabel = switch (r.priority) {
      RecPriority.high => l.resPriHigh,
      RecPriority.medium => l.resPriMed,
      RecPriority.low => l.resPriLow,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: r.accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: r.accent.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [r.accent, r.accent.withOpacity(0.78)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: r.accent.withOpacity(0.32),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(r.icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: context.tea.ink,
                      letterSpacing: 0.4,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: priorityColor.withOpacity(0.32),
                    ),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Detail
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                r.detail,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.tea.sub,
                  height: 1.4,
                ),
              ),
            ),
            // Evidence chip
            if (r.evidence != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights_rounded,
                          size: 10, color: r.accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          r.evidence!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: r.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sticky bottom CTA ───────────────────────────────────────────────────
  Widget _buildBottomCta() {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.tea.bgBottom,
        border: Border(
          top: BorderSide(color: context.tea.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_teaPrimary, _teaMid, _teaBright],
              ),
              boxShadow: [
                BoxShadow(
                  color: _teaPrimary.withOpacity(0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainScreen(startingIndex: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        l.resCaptureAnother,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Harvest Urgency — domain-tailored hero card
  // ───────────────────────────────────────────────────────────────────────
  _UrgencyData _computeUrgency() {
    final l = AppLocalizations.of(context);
    final unknown = _UrgencyData(
      level: 'UNKNOWN',
      headline: l.urgHeadInsufficient,
      subline: l.urgSubInsufficient,
      icon: Icons.help_outline_rounded,
      gradient: const [Color(0xFF4B5563), Color(0xFF6B7280)],
      urgencyLevel: 0,
      progressLabel: '—',
    );

    if (timeline.isEmpty) return unknown;

    final startRaw =
        (payload['startingQuality'] ?? payload['quality'] ?? '').toString();
    final startM = RegExp(r'T([1-4])').firstMatch(startRaw);
    if (startM == null) return unknown;

    final startT = int.parse(startM.group(1)!);
    final startScore = 5 - startT;
    final startTier = 'T$startT';

    if (startT == 4) {
      return _UrgencyData(
        level: 'PAST PRIME',
        headline: l.urgHeadProcessNow,
        subline: l.urgSubProcessNow,
        icon: Icons.gpp_bad_rounded,
        gradient: const [
          Color(0xFF3F1D38),
          Color(0xFF7C2D12),
          Color(0xFFB91C1C),
        ],
        urgencyLevel: 1.0,
        progressLabel: l.urgProgNoWindow,
        fromTier: 'T4',
      );
    }

    int? dropDay;
    int? dropScore;
    int prevScore = startScore;
    for (final t in timeline) {
      final pq = (t['pred_q'] as num).toInt();
      if (pq < prevScore) {
        dropDay = (t['day'] as num).toInt();
        dropScore = pq;
        break;
      }
      prevScore = pq;
    }

    if (dropDay == null || dropScore == null) {
      return _UrgencyData(
        level: 'STABLE',
        headline: l.urgHeadHolding,
        subline: l.urgSubHolding(startTier),
        icon: Icons.workspace_premium_rounded,
        gradient: const [
          Color(0xFF064E3B),
          Color(0xFF047857),
          Color(0xFF10B981),
        ],
        urgencyLevel: 0.0,
        progressLabel: l.urgProgFullWindow,
        fromTier: startTier,
      );
    }

    final toTier = 'T${5 - dropScore}';
    final dropDate = DateTime.now().add(Duration(days: dropDay));
    final urgency = ((15 - dropDay) / 15).clamp(0.0, 1.0);

    String level;
    String headline;
    List<Color> gradient;
    IconData icon;

    if (dropDay <= 1) {
      level = 'CRITICAL';
      headline = l.urgHeadToday;
      gradient = const [
        Color(0xFF7F1D1D),
        Color(0xFFDC2626),
        Color(0xFFEA580C),
      ];
      icon = Icons.warning_amber_rounded;
    } else if (dropDay <= 3) {
      level = 'HIGH';
      headline = l.urgHeadWithin(dropDay);
      gradient = const [
        Color(0xFFB45309),
        Color(0xFFD97706),
        Color(0xFFF59E0B),
      ];
      icon = Icons.local_fire_department_rounded;
    } else if (dropDay <= 7) {
      level = 'MODERATE';
      headline = l.urgHeadPlan(dropDay);
      gradient = const [
        Color(0xFF166534),
        Color(0xFFCA8A04),
        Color(0xFFEAB308),
      ];
      icon = Icons.hourglass_top_rounded;
    } else {
      level = 'COMFORTABLE';
      headline = l.urgHeadWindow(dropDay);
      gradient = const [
        Color(0xFF064E3B),
        Color(0xFF047857),
        Color(0xFF22C55E),
      ];
      icon = Icons.eco_rounded;
    }

    return _UrgencyData(
      level: level,
      headline: headline,
      subline: l.urgSubDrop(dropDay, startTier, toTier),
      icon: icon,
      gradient: gradient,
      daysUntilDrop: dropDay,
      fromTier: startTier,
      toTier: toTier,
      dropDate: dropDate,
      urgencyLevel: urgency,
      progressLabel: l.urgProgLeft(dropDay),
    );
  }

  String _levelLabel(AppLocalizations l, String level) {
    switch (level) {
      case 'PAST PRIME':
        return l.urgLevelPastPrime;
      case 'STABLE':
        return l.urgLevelStable;
      case 'CRITICAL':
        return l.urgLevelCritical;
      case 'HIGH':
        return l.urgLevelHigh;
      case 'MODERATE':
        return l.urgLevelModerate;
      case 'COMFORTABLE':
        return l.urgLevelComfortable;
      default:
        return l.urgLevelUnknown;
    }
  }

  Widget _buildUrgencyCard() {
    final l = AppLocalizations.of(context);
    final u = _computeUrgency();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: u.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: u.gradient.first.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative tea-leaf pattern
            Positioned(
              right: -28,
              top: -28,
              child: Icon(
                Icons.eco_rounded,
                size: 170,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -20,
              child: Icon(
                u.icon,
                size: 120,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: icon · label · level pill
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                            width: 1,
                          ),
                        ),
                        child: Icon(u.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.urgTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.40),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _levelLabel(l, u.level),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Hero: big number + headline + subline
                  if (u.daysUntilDrop != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              u.daysUntilDrop.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 58,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -2.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.urgDayUnit(u.daysUntilDrop!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.headline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                u.subline,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.93),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            u.subline,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.93),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),

                  // ── Tier transition + date
                  if (u.fromTier != null)
                    Row(
                      children: [
                        _tierBadge(u.fromTier!, Colors.white.withOpacity(0.22)),
                        if (u.toTier != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white.withOpacity(0.85),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          _tierBadge(
                              u.toTier!, Colors.black.withOpacity(0.28)),
                        ],
                        const Spacer(),
                        if (u.dropDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  color: Colors.white.withOpacity(0.95),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  DateFormat('EEE, d MMM')
                                      .format(u.dropDate!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 14),

                  // ── Urgency gauge
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: u.urgencyLevel,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(u.urgencyLevel * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    u.progressLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierBadge(String tier, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.40),
            width: 1,
          ),
        ),
        child: Text(
          tier,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      );

  // ───────────────────────────────────────────────────────────────────────
  //  Economic Impact — value preserved by harvesting before the drop
  // ───────────────────────────────────────────────────────────────────────
  _ImpactData _computeImpact() {
    final l = AppLocalizations.of(context);
    final u = _computeUrgency();

    final startTier = u.fromTier;
    final terminalTier = u.toTier ?? u.fromTier;

    final startPrice = startTier == null ? 0.0 : (_prices[startTier] ?? 0.0);
    final endPrice =
        terminalTier == null ? 0.0 : (_prices[terminalTier] ?? 0.0);
    final perKg = (startPrice - endPrice).clamp(0.0, double.infinity);
    final totalAtRisk = perKg * _batchKg;
    final totalCurrentValue = startPrice * _batchKg;

    String pitch;
    if (u.level == 'PAST PRIME') {
      pitch = l.econPitchExpired;
    } else if (u.level == 'STABLE' || u.toTier == null || perKg == 0) {
      pitch =
          l.econPitchStable(startTier ?? '', _money.format(totalCurrentValue));
    } else {
      pitch = l.econPitchDrop(
          u.daysUntilDrop ?? 0, _money.format(perKg), terminalTier ?? '');
    }

    return _ImpactData(
      perKgPreserved: perKg,
      totalAtRisk: totalAtRisk,
      currentValuePerKg: startPrice,
      projectedValuePerKg: endPrice,
      fromTier: startTier,
      toTier: terminalTier,
      pitch: pitch,
      isStable: u.level == 'STABLE',
      isExpired: u.level == 'PAST PRIME',
    );
  }

  Widget _buildImpactCard() {
    final l = AppLocalizations.of(context);
    final d = _computeImpact();

    final gradient = d.isExpired
        ? const [Color(0xFF1F2937), Color(0xFF4B5563), Color(0xFF6B7280)]
        : d.isStable
            ? const [Color(0xFF14532D), Color(0xFF166534), Color(0xFF15803D)]
            : const [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFF59E0B)];

    final showSavings = !d.isStable && !d.isExpired && d.perKgPreserved > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // tea-liquor swirl backdrop
            Positioned(
              left: -30,
              bottom: -30,
              child: Icon(
                Icons.savings_rounded,
                size: 160,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                Icons.local_florist_rounded,
                size: 120,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.econTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openPriceEditor,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.40),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded,
                                  color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                l.econRates,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Hero figure
                  if (showSavings)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.econPreserve,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _money.format(d.perKgPreserved),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '/ kg',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      d.isExpired ? l.econAtMinGrade : l.econNoLoss,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),

                  const SizedBox(height: 8),
                  Text(
                    d.pitch,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.93),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),

                  // ── Per-kg rate comparison
                  if (showSavings) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.econNow,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (d.fromTier != null)
                                      _tierBadge(d.fromTier!,
                                          Colors.white.withOpacity(0.22)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_money.format(d.currentValuePerKg)}/kg',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.econIfWaited,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (d.toTier != null)
                                      _tierBadge(d.toTier!,
                                          Colors.black.withOpacity(0.28)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_money.format(d.projectedValuePerKg)}/kg',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── Batch size + total at risk
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _openBatchEditor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.28),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.scale_rounded,
                                    color: Colors.white.withOpacity(0.95),
                                    size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  l.econBatch,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_batchKg.toStringAsFixed(_batchKg % 1 == 0 ? 0 : 1)} kg',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.edit_rounded,
                                    color: Colors.white.withOpacity(0.75),
                                    size: 13),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showSavings ? l.econAtRisk : l.econBatchValue,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _money.format(showSavings
                                    ? d.totalAtRisk
                                    : d.currentValuePerKg * _batchKg),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Price editor ────────────────────────────────────────────────────────
  Future<void> _openPriceEditor() async {
    final l = AppLocalizations.of(context);
    final controllers = {
      for (final t in ['T1', 'T2', 'T3', 'T4'])
        t: TextEditingController(
          text: (_prices[t] ?? PricingService.defaultPrices[t]!)
              .toStringAsFixed(0),
        ),
    };

    final tierLabel = {
      'T1': l.tierHighest,
      'T2': l.tierGood,
      'T3': l.tierAverage,
      'T4': l.tierPoor,
    };
    final tierDesc = {
      'T1': l.prcDescT1,
      'T2': l.prcDescT2,
      'T3': l.prcDescT3,
      'T4': l.prcDescT4,
    };
    const tierColor = {
      'T1': Color(0xFF15803D),
      'T2': Color(0xFF65A30D),
      'T3': Color(0xFFCA8A04),
      'T4': Color(0xFFB91C1C),
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.tea.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.tea.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.tea.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.local_florist_rounded,
                              color: context.tea.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.factoryRateCard,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.tea.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.prcRateCardSub,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.tea.sub,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    for (final tier in ['T1', 'T2', 'T3', 'T4'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _priceField(
                          tier: tier,
                          label: tierLabel[tier]!,
                          desc: tierDesc[tier]!,
                          accent: tierColor[tier]!,
                          controller: controllers[tier]!,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await PricingService.resetToDefaults();
                              final indicative =
                                  PricingService.indicativePrices();
                              for (final t in ['T1', 'T2', 'T3', 'T4']) {
                                controllers[t]!.text =
                                    (indicative[t] ?? 0).toStringAsFixed(0);
                              }
                            },
                            icon: const Icon(Icons.restart_alt_rounded,
                                size: 18),
                            label: Text(l.prcReset),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade800,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final newPrices = <String, double>{};
                              for (final t in ['T1', 'T2', 'T3', 'T4']) {
                                final v =
                                    double.tryParse(controllers[t]!.text) ??
                                        PricingService.defaultPrices[t]!;
                                newPrices[t] = v.clamp(0.0, 100000.0);
                              }
                              await PricingService.savePrices(newPrices);
                              if (!mounted) return;
                              setState(() => _prices = newPrices);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(l.prcSaveRates),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _priceField({
    required String tier,
    required String label,
    required String desc,
    required Color accent,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.tea.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.tea.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                tier,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.tea.sub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: 'Rs ',
                prefixStyle: TextStyle(
                  color: context.tea.sub,
                  fontWeight: FontWeight.w600,
                ),
                suffixText: '/kg',
                suffixStyle: TextStyle(
                  color: context.tea.faint,
                  fontSize: 11,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.tea.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Batch size editor ───────────────────────────────────────────────────
  Future<void> _openBatchEditor() async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(
      text: _batchKg.toStringAsFixed(_batchKg % 1 == 0 ? 0 : 1),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.scale_rounded, color: context.tea.accent),
            const SizedBox(width: 8),
            Text(l.batchTitle),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.batchPrompt,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.tea.sub,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  suffixText: 'kg',
                  suffixStyle: TextStyle(
                    color: context.tea.sub,
                    fontWeight: FontWeight.w600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null) return l.batchErrNumber;
                  if (n <= 0) return l.batchErrPositive;
                  if (n > 100000) return l.batchErrTooLarge;
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [1, 10, 50, 100, 500].map((q) {
                  return ActionChip(
                    label: Text('$q kg'),
                    onPressed: () => ctrl.text = q.toString(),
                    backgroundColor: context.tea.surface,
                    labelStyle: TextStyle(
                      color: context.tea.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final n = double.parse(ctrl.text);
              await PricingService.saveBatchKg(n);
              if (!mounted) return;
              setState(() => _batchKg = n);
              Navigator.pop(ctx);
            },
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
  }
}

class _ImpactData {
  final double perKgPreserved;
  final double totalAtRisk;
  final double currentValuePerKg;
  final double projectedValuePerKg;
  final String? fromTier;
  final String? toTier;
  final String pitch;
  final bool isStable;
  final bool isExpired;

  const _ImpactData({
    required this.perKgPreserved,
    required this.totalAtRisk,
    required this.currentValuePerKg,
    required this.projectedValuePerKg,
    required this.pitch,
    required this.isStable,
    required this.isExpired,
    this.fromTier,
    this.toTier,
  });
}

class _UrgencyData {
  final String level;
  final String headline;
  final String subline;
  final IconData icon;
  final List<Color> gradient;
  final int? daysUntilDrop;
  final String? fromTier;
  final String? toTier;
  final DateTime? dropDate;
  final double urgencyLevel;
  final String progressLabel;

  const _UrgencyData({
    required this.level,
    required this.headline,
    required this.subline,
    required this.icon,
    required this.gradient,
    required this.urgencyLevel,
    required this.progressLabel,
    this.daysUntilDrop,
    this.fromTier,
    this.toTier,
    this.dropDate,
  });
}
