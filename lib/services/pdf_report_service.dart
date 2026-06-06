// lib/services/pdf_report_service.dart
//
// Builds a one-page A4 quality-forecast report from the same data that
// powers the result screen. The output is a `Uint8List` of PDF bytes
// ready to hand to the `printing` package for share / save / print.
//
// Visual language mirrors the in-app screen: tea-green palette, tier
// transition badges, urgency gradient, AI insights, action plan.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/services.dart' show rootBundle;

import 'recommendation_engine.dart';

class _Palette {
  static const deep = PdfColor.fromInt(0xFF0F3D2E);
  static const primary = PdfColor.fromInt(0xFF1B5E3F);
  static const mid = PdfColor.fromInt(0xFF2E7D5B);
  static const bright = PdfColor.fromInt(0xFF22C55E);
  static const surface = PdfColor.fromInt(0xFFE7F4EB);
  static const surfaceAlt = PdfColor.fromInt(0xFFF4F9F5);
  static const border = PdfColor.fromInt(0xFFD9E8DE);
  static const gold = PdfColor.fromInt(0xFFD4A82C);
  static const muted = PdfColor.fromInt(0xFF6B7280);
  static const charcoal = PdfColor.fromInt(0xFF1F2937);

  static PdfColor tier(String t) {
    switch (t) {
      case 'T1':
        return const PdfColor.fromInt(0xFF0F4D2E);
      case 'T2':
        return const PdfColor.fromInt(0xFF3E7D4E);
      case 'T3':
        return const PdfColor.fromInt(0xFFB8843A);
      case 'T4':
        return const PdfColor.fromInt(0xFFA04823);
      default:
        return muted;
    }
  }

  static PdfColor priority(RecPriority p) {
    switch (p) {
      case RecPriority.high:
        return const PdfColor.fromInt(0xFFD9534F);
      case RecPriority.medium:
        return const PdfColor.fromInt(0xFFD4A82C);
      case RecPriority.low:
        return mid;
    }
  }
}

class PdfReportService {
  // Latin letter-spacing splits Sinhala/Tamil conjuncts and vowel signs apart,
  // so tracking is suppressed for those scripts (kept for English).
  static bool _noTracking = false;

  static Future<Uint8List> generate({
    required AppLocalizations l,
    required List<dynamic> timeline,
    required List<dynamic> milestones,
    required String startingQuality,
    required String terminalTier,
    required int leafAge,
    required Map<String, double> prices,
    required double batchKg,
    required String place,
    required String currentTemp,
    required String currentHum,
    required String currentRain,
    String? imageBase64,
  }) async {
    final doc = pw.Document(
      title: 'TeaOptima Quality Forecast',
      author: 'TeaOptima',
    );

    final money = NumberFormat.currency(
      locale: 'en_LK',
      symbol: 'Rs ',
      decimalDigits: 0,
    );
    final now = DateTime.now();
    final reportTs = DateFormat('d MMM yyyy, HH:mm').format(now);

    // Embed a Unicode font so Sinhala/Tamil glyphs render (the built-in PDF
    // font is Latin-only). English uses the default font.
    final theme = await _localeTheme(l.localeName);
    _noTracking = l.localeName != 'en';

    final startShort = _short(startingQuality);
    final endShort = _short(terminalTier);
    final lastDay =
        timeline.isEmpty ? 0 : (timeline.last['day'] as num).toInt();
    final terminalDate = now.add(Duration(days: lastDay));

    // ── derive urgency + impact + insights with the same logic as the screen
    final urgency = _Urgency.from(timeline, startShort, l);
    final impact = _Impact.from(urgency, prices, batchKg, l, money);
    final insights = RecommendationEngine.generate(
      l: l,
      timeline: timeline,
      milestones: milestones,
      startingQuality: startingQuality,
      leafAge: leafAge,
      prices: prices,
      batchKg: batchKg,
    );

    Uint8List? imgBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imgBytes = base64Decode(imageBase64);
      } catch (_) {}
    }

    // Per-day SHAP drivers for the terminal (final-grade) day, if present.
    final dayFactors = (timeline.isNotEmpty && timeline.last['factors'] is List)
        ? (timeline.last['factors'] as List)
        : const <dynamic>[];
    final hasDrivers = dayFactors.isNotEmpty;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
        build: (ctx) => [
          _header(l, reportTs, place, leafAge, batchKg),
          pw.SizedBox(height: 14),
          _heroJourney(
              l, startShort, endShort, lastDay, terminalDate, urgency, money),
          pw.SizedBox(height: 12),
          _impactSection(l, impact, money, startShort, endShort),
          pw.SizedBox(height: 12),
          _trajectoryTable(l, timeline),
          pw.SizedBox(height: 12),
          if (hasDrivers) _keyDrivers(l, timeline, now),
          if (hasDrivers) pw.SizedBox(height: 12),
          if (insights.isNotEmpty) _insightsSection(l, insights),
          if (insights.isNotEmpty) pw.SizedBox(height: 12),
          _actionPlan(l, milestones, now),
          pw.SizedBox(height: 12),
          _fieldConditions(l, place, currentTemp, currentHum, currentRain),
          if (imgBytes != null) ...[
            pw.SizedBox(height: 12),
            _leafSample(l, imgBytes),
          ],
          pw.SizedBox(height: 14),
          _footer(l, reportTs),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header band ─────────────────────────────────────────────────────────
  static pw.Widget _header(AppLocalizations l, String ts, String place,
      int leafAge, double batchKg) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: const [_Palette.deep, _Palette.primary, _Palette.mid],
        ),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'T',
                        style: pw.TextStyle(
                          color: _Palette.primary,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'TEAOPTIMA',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: _track(2.2),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  l.pdfReportTitle,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  l.pdfGenerated(ts),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _miniMeta(l.resLocation, place),
              pw.SizedBox(height: 6),
              _miniMeta(l.resLeafAgeLabel, '$leafAge ${l.histDayShort}'),
              pw.SizedBox(height: 6),
              _miniMeta(l.econBatch,
                  '${batchKg.toStringAsFixed(batchKg % 1 == 0 ? 0 : 1)} kg'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniMeta(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: const PdfColor.fromInt(0xCCFFFFFF),
            fontSize: 7,
            letterSpacing: _track(1.2),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Hero: tier journey + urgency ────────────────────────────────────────
  static pw.Widget _heroJourney(
    AppLocalizations l,
    String startTier,
    String endTier,
    int lastDay,
    DateTime terminalDate,
    _Urgency urgency,
    NumberFormat money,
  ) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.resQualityTrajectory, icon: '📈'),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _tierBadge(startTier, big: true),
              pw.SizedBox(width: 10),
              pw.Text('→',
                  style: pw.TextStyle(
                      fontSize: 18,
                      color: _Palette.muted,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              _tierBadge(endTier, big: true),
              pw.SizedBox(width: 14),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    l.pdfTerminalGrade,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: _Palette.muted,
                      letterSpacing: _track(1.4),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${DateFormat('EEEE, d MMM yyyy').format(terminalDate)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _Palette.deep,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: urgency.gradient,
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0x33FFFFFF),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    _pdfLevelLabel(l, urgency.level),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      letterSpacing: _track(1.3),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        urgency.headline,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        urgency.subline,
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9.5,
                          lineSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Economic impact ─────────────────────────────────────────────────────
  static pw.Widget _impactSection(
    AppLocalizations l,
    _Impact impact,
    NumberFormat money,
    String fromTier,
    String toTier,
  ) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.econTitle, icon: 'Rs'),
          pw.SizedBox(height: 10),
          if (impact.showSavings) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l.pdfPreserveNow,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: _Palette.muted,
                        letterSpacing: _track(1.4),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          money.format(impact.perKg),
                          style: pw.TextStyle(
                            fontSize: 26,
                            color: _Palette.deep,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          ' / kg',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: _Palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      l.pdfTotalAtRisk,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: _Palette.muted,
                        letterSpacing: _track(1.4),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      money.format(impact.totalAtRisk),
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: _Palette.deep,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _ratePill(l.econNow, fromTier, impact.currentValue, money),
                pw.SizedBox(width: 8),
                pw.Text('→',
                    style: pw.TextStyle(
                        color: _Palette.muted,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 8),
                _ratePill(
                    l.econIfWaited, toTier, impact.projectedValue, money),
              ],
            ),
          ] else
            pw.Text(
              impact.pitch,
              style: pw.TextStyle(
                fontSize: 11,
                color: _Palette.deep,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _ratePill(
      String tag, String tier, double rate, NumberFormat money) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _Palette.surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _Palette.border),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            tag,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: _Palette.muted,
              letterSpacing: _track(1.4),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 6),
          _tierBadge(tier, big: false),
          pw.SizedBox(width: 6),
          pw.Text(
            '${money.format(rate)}/kg',
            style: pw.TextStyle(
              fontSize: 10,
              color: _Palette.deep,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── 15-day trajectory table ─────────────────────────────────────────────
  static pw.Widget _trajectoryTable(AppLocalizations l, List<dynamic> timeline) {
    final headerStyle = pw.TextStyle(
      fontSize: 8.5,
      color: _Palette.muted,
      letterSpacing: _track(1.1),
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = pw.TextStyle(fontSize: 9.5, color: _Palette.charcoal);

    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.pdfForecast15),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(0.8),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.0),
              5: pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: _Palette.surface,
                ),
                children: [
                  _cell(l.pdfColDay, headerStyle, header: true),
                  _cell(l.pdfColDate, headerStyle, header: true),
                  _cell(l.pdfColGrade, headerStyle, header: true),
                  _cell(l.pdfColTemp, headerStyle, header: true),
                  _cell(l.pdfColHum, headerStyle, header: true),
                  _cell(l.pdfColRain, headerStyle, header: true),
                ],
              ),
              ...timeline.map((t) {
                final day = (t['day'] as num).toInt();
                final date = DateFormat('d MMM')
                    .format(DateTime.now().add(Duration(days: day)));
                final tierLabel = (t['tier'] ?? '').toString();
                final tierShort = _short(tierLabel);
                return pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                          color: _Palette.border, width: 0.5),
                    ),
                  ),
                  children: [
                    _cell(day.toString(), cellStyle),
                    _cell(date, cellStyle),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      child: pw.Row(
                        children: [
                          _tierBadge(tierShort, big: false),
                        ],
                      ),
                    ),
                    _cell(
                        (t['temp'] as num).toDouble().toStringAsFixed(1),
                        cellStyle),
                    _cell(
                        (t['hum'] as num).toDouble().toStringAsFixed(0),
                        cellStyle),
                    _cell(
                        (t['rain'] as num).toDouble().toStringAsFixed(1),
                        cellStyle),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String s, pw.TextStyle style,
      {bool header = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(
          horizontal: 4, vertical: header ? 6 : 5),
      child: pw.Text(s, style: style),
    );
  }

  // ── Per-day SHAP drivers (mirrors the in-app contribution bars) ──────────
  static pw.Widget _keyDrivers(
      AppLocalizations l, List<dynamic> timeline, DateTime now) {
    final last = timeline.last as Map;
    final raw = last['factors'];
    final factors = (raw is List) ? raw.whereType<Map>().toList() : <Map>[];
    final tier = _short((last['tier'] ?? '').toString());
    final day = (last['day'] is num) ? (last['day'] as num).toInt() : 0;
    final date = DateFormat('d MMM').format(now.add(Duration(days: day)));
    final maxAbs = factors
        .fold<double>(0.0, (m, f) {
          final c = (f['contribution'] as num?)?.toDouble().abs() ?? 0.0;
          return c > m ? c : m;
        })
        .clamp(1e-6, double.infinity);

    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.resWhatDrives, suffix: '$tier · $date'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _driverLegend(_Palette.primary, l.factorProtects),
            pw.SizedBox(width: 16),
            _driverLegend(const PdfColor.fromInt(0xFFB8843A), l.factorDegrades),
          ]),
          pw.SizedBox(height: 10),
          ...factors.map((f) => _driverBar(l, f, maxAbs)),
        ],
      ),
    );
  }

  static pw.Widget _driverLegend(PdfColor c, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 7,
          height: 7,
          decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: _Palette.muted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _driverBar(AppLocalizations l, Map f, double maxAbs) {
    final key = (f['key'] ?? '').toString();
    final contribution = (f['contribution'] as num?)?.toDouble() ?? 0.0;
    final value = (f['value'] as num?)?.toDouble();
    final degrading = contribution < 0;
    final color =
        degrading ? const PdfColor.fromInt(0xFFB8843A) : _Palette.primary;
    final frac = (contribution.abs() / maxAbs).clamp(0.0, 1.0);
    final int filled = (frac * 100).round().clamp(1, 100).toInt();
    final int empty = 100 - filled;
    final valStr = _factorValue(key, value);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  _factorLabel(l, key),
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    color: _Palette.deep,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (valStr.isNotEmpty)
                pw.Text(
                  valStr,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _Palette.muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.ClipRRect(
            horizontalRadius: 3,
            verticalRadius: 3,
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: filled,
                  child: pw.Container(height: 6, color: color),
                ),
                if (empty > 0)
                  pw.Expanded(
                    flex: empty,
                    child: pw.Container(height: 6, color: _Palette.surface),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _factorLabel(AppLocalizations l, String key) {
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

  static String _factorValue(String key, double? value) {
    if (value == null) return '';
    if (key == 'day_quality') {
      final s = value.round().clamp(1, 4);
      return 'T${5 - s}';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  // ── Expert recommendations ──────────────────────────────────────────────
  static pw.Widget _insightsSection(
      AppLocalizations l, List<Recommendation> insights) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.pdfExpertRec,
              suffix: l.resInsightCount(insights.length)),
          pw.SizedBox(height: 8),
          ...insights.asMap().entries.map((e) {
            final isLast = e.key == insights.length - 1;
            return _insightRow(l, e.value, isLast);
          }),
        ],
      ),
    );
  }

  static pw.Widget _insightRow(
      AppLocalizations l, Recommendation r, bool isLast) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: isLast ? 0 : 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0x0D1B5E3F),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
            color: const PdfColor.fromInt(0x331B5E3F), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  r.title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _Palette.deep,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: _track(0.3),
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: _Palette.priority(r.priority),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  switch (r.priority) {
                    RecPriority.high => l.resPriHigh,
                    RecPriority.medium => l.resPriMed,
                    RecPriority.low => l.resPriLow,
                  },
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: _track(0.6),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            r.detail,
            style: pw.TextStyle(
              fontSize: 9,
              color: _Palette.charcoal,
              lineSpacing: 1.3,
            ),
          ),
          if (r.evidence != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              l.pdfEvidence(r.evidence!),
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _Palette.muted,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action plan ─────────────────────────────────────────────────────────
  static pw.Widget _actionPlan(
      AppLocalizations l, List<dynamic> milestones, DateTime now) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.resActionPlan),
          pw.SizedBox(height: 8),
          if (milestones.isEmpty)
            pw.Text(
              l.resT4NotSuitable,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: const PdfColor.fromInt(0xFFB91C1C),
                fontWeight: pw.FontWeight.bold,
              ),
            )
          else
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: milestones.map<pw.Widget>((m) {
                final rec =
                    (m['recommendation'] ?? '').toString().replaceAll('**', '');
                final tierM = RegExp(r'T[1-4]').firstMatch(rec);
                final tier = tierM?.group(0) ?? '';
                final dayM =
                    RegExp(r'day (-?\d+)').firstMatch(rec.toLowerCase());
                String when = '';
                if (dayM != null) {
                  final d = int.parse(dayM.group(1)!);
                  when = d <= 0
                      ? l.resToday
                      : DateFormat('d MMM').format(now.add(Duration(days: d)));
                }
                final tierC = _Palette.tier(tier);
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(tierC.red, tierC.green, tierC.blue, 0.06),
                    border: pw.Border.all(
                      color:
                          PdfColor(tierC.red, tierC.green, tierC.blue, 0.20),
                      width: 0.5,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      _tierBadge(tier, big: false),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        l.pdfBefore(when),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          color: _Palette.deep,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Current field conditions ────────────────────────────────────────────
  static pw.Widget _fieldConditions(AppLocalizations l, String place,
      String temp, String hum, String rain) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.resFieldConditions, suffix: place),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _weatherStat(l.resTemperature, temp,
                  const PdfColor.fromInt(0xFFD9534F)),
              pw.SizedBox(width: 8),
              _weatherStat(
                  l.homeHumidity, hum, const PdfColor.fromInt(0xFF3B82F6)),
              pw.SizedBox(width: 8),
              _weatherStat(
                  l.resRainfall, rain, const PdfColor.fromInt(0xFF6B7280)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _weatherStat(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red, color.green, color.blue, 0.07),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
            color: PdfColor(color.red, color.green, color.blue, 0.22),
            width: 0.5,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _Palette.muted,
                letterSpacing: _track(1.2),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                color: _Palette.deep,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Optional leaf sample image ──────────────────────────────────────────
  static pw.Widget _leafSample(AppLocalizations l, Uint8List imgBytes) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.pdfLeafSample),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                pw.MemoryImage(imgBytes),
                height: 130,
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer band ─────────────────────────────────────────────────────────
  static pw.Widget _footer(AppLocalizations l, String ts) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _Palette.surface,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            l.pdfFooter,
            style: pw.TextStyle(
              fontSize: 8,
              color: _Palette.primary,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: _track(0.6),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            ts,
            style: pw.TextStyle(
              fontSize: 8,
              color: _Palette.muted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared primitives ───────────────────────────────────────────────────
  static pw.Widget _surfaceCard({required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _Palette.border, width: 0.5),
      ),
      child: child,
    );
  }

  static pw.Widget _sectionTitle(String title,
      {String? suffix, String? icon}) {
    return pw.Row(
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: _Palette.surface,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8.5,
              color: _Palette.primary,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: _track(1.4),
            ),
          ),
        ),
        if (suffix != null) ...[
          pw.SizedBox(width: 6),
          pw.Text(
            suffix,
            style: pw.TextStyle(
              fontSize: 8,
              color: _Palette.muted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _tierBadge(String tier, {required bool big}) {
    final c = _Palette.tier(tier);
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: big ? 12 : 6,
        vertical: big ? 6 : 2.5,
      ),
      decoration: pw.BoxDecoration(
        color: c,
        borderRadius: pw.BorderRadius.circular(big ? 8 : 4),
      ),
      child: pw.Text(
        tier,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: big ? 13 : 8.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: _track(0.4),
        ),
      ),
    );
  }

  static double? _track(double v) => _noTracking ? null : v;

  static String _short(String t) =>
      RegExp(r'T[1-4]').firstMatch(t)?.group(0) ?? '—';

  // Build a PDF theme whose fonts cover the export language's script, loaded
  // from bundled assets so reports render fully offline. For Sinhala/Tamil the
  // script font is the base (and bold), giving proper weights, with Noto Sans
  // as a fallback for any Latin/symbol glyphs. English keeps the built-in font.
  static Future<pw.ThemeData?> _localeTheme(String lang) async {
    try {
      final String basePath, boldPath;
      if (lang == 'si') {
        basePath = 'assets/fonts/NotoSansSinhala-Regular.ttf';
        boldPath = 'assets/fonts/NotoSansSinhala-Bold.ttf';
      } else if (lang == 'ta') {
        basePath = 'assets/fonts/NotoSansTamil-Regular.ttf';
        boldPath = 'assets/fonts/NotoSansTamil-Bold.ttf';
      } else {
        return null; // English → built-in Latin font is sufficient
      }
      final latinFallback =
          pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      return pw.ThemeData.withFont(
        base: pw.Font.ttf(await rootBundle.load(basePath)),
        bold: pw.Font.ttf(await rootBundle.load(boldPath)),
        fontFallback: [latinFallback],
      );
    } catch (_) {
      return null; // asset missing / load failure → default theme (no crash)
    }
  }

  static String _pdfLevelLabel(AppLocalizations l, String level) {
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
}

// ── derived helpers ───────────────────────────────────────────────────────
class _Urgency {
  final String level;
  final String headline;
  final String subline;
  final List<PdfColor> gradient;
  final int? dropDay;
  final String? fromTier;
  final String? toTier;

  const _Urgency({
    required this.level,
    required this.headline,
    required this.subline,
    required this.gradient,
    this.dropDay,
    this.fromTier,
    this.toTier,
  });

  static _Urgency from(
      List<dynamic> timeline, String startTier, AppLocalizations l) {
    final startM = RegExp(r'T([1-4])').firstMatch(startTier);
    if (startM == null || timeline.isEmpty) {
      return _Urgency(
        level: 'UNKNOWN',
        headline: l.urgHeadInsufficient,
        subline: l.urgSubInsufficient,
        gradient: const [
          PdfColor.fromInt(0xFF4B5563),
          PdfColor.fromInt(0xFF6B7280),
        ],
      );
    }
    final startT = int.parse(startM.group(1)!);
    if (startT == 4) {
      return _Urgency(
        level: 'PAST PRIME',
        headline: l.urgHeadProcessNow,
        subline: l.urgSubProcessNow,
        gradient: const [
          PdfColor.fromInt(0xFF3F1D38),
          PdfColor.fromInt(0xFFB91C1C),
        ],
        fromTier: 'T4',
      );
    }

    final startScore = 5 - startT;
    int? dropDay;
    int? dropScore;
    int prev = startScore;
    for (final t in timeline) {
      final pq = (t['pred_q'] as num).toInt();
      if (pq < prev) {
        dropDay = (t['day'] as num).toInt();
        dropScore = pq;
        break;
      }
      prev = pq;
    }
    if (dropDay == null || dropScore == null) {
      return _Urgency(
        level: 'STABLE',
        headline: l.urgHeadHolding,
        subline: l.urgSubHolding('T$startT'),
        gradient: const [
          PdfColor.fromInt(0xFF064E3B),
          PdfColor.fromInt(0xFF10B981),
        ],
        fromTier: 'T$startT',
      );
    }
    final toTier = 'T${5 - dropScore}';
    String level, headline;
    List<PdfColor> gradient;
    if (dropDay <= 1) {
      level = 'CRITICAL';
      headline = l.urgHeadToday;
      gradient = const [
        PdfColor.fromInt(0xFF7F1D1D),
        PdfColor.fromInt(0xFFEA580C),
      ];
    } else if (dropDay <= 3) {
      level = 'HIGH';
      headline = l.urgHeadWithin(dropDay);
      gradient = const [
        PdfColor.fromInt(0xFFB45309),
        PdfColor.fromInt(0xFFF59E0B),
      ];
    } else if (dropDay <= 7) {
      level = 'MODERATE';
      headline = l.urgHeadPlan(dropDay);
      gradient = const [
        PdfColor.fromInt(0xFF166534),
        PdfColor.fromInt(0xFFEAB308),
      ];
    } else {
      level = 'COMFORTABLE';
      headline = l.urgHeadWindow(dropDay);
      gradient = const [
        PdfColor.fromInt(0xFF064E3B),
        PdfColor.fromInt(0xFF22C55E),
      ];
    }
    return _Urgency(
      level: level,
      headline: headline,
      subline: l.urgSubDrop(dropDay, 'T$startT', toTier),
      gradient: gradient,
      dropDay: dropDay,
      fromTier: 'T$startT',
      toTier: toTier,
    );
  }
}

class _Impact {
  final double perKg;
  final double totalAtRisk;
  final double currentValue;
  final double projectedValue;
  final bool showSavings;
  final String pitch;

  const _Impact({
    required this.perKg,
    required this.totalAtRisk,
    required this.currentValue,
    required this.projectedValue,
    required this.showSavings,
    required this.pitch,
  });

  static _Impact from(_Urgency u, Map<String, double> prices, double batchKg,
      AppLocalizations l, NumberFormat money) {
    final from = u.fromTier;
    final to = u.toTier ?? u.fromTier;
    final fromPrice = from == null ? 0.0 : (prices[from] ?? 0.0);
    final toPrice = to == null ? 0.0 : (prices[to] ?? 0.0);
    final perKg = (fromPrice - toPrice).clamp(0.0, double.infinity);
    final total = perKg * batchKg;
    final showSavings =
        u.level != 'STABLE' && u.level != 'PAST PRIME' && perKg > 0;
    final pitch = u.level == 'PAST PRIME'
        ? l.econPitchExpired
        : l.econPitchStable(
            u.fromTier ?? '', money.format(fromPrice * batchKg));
    return _Impact(
      perKg: perKg,
      totalAtRisk: total,
      currentValue: fromPrice,
      projectedValue: toPrice,
      showSavings: showSavings,
      pitch: pitch,
    );
  }
}
