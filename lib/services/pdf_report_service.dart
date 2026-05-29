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

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
  static Future<Uint8List> generate({
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

    final startShort = _short(startingQuality);
    final endShort = _short(terminalTier);
    final lastDay =
        timeline.isEmpty ? 0 : (timeline.last['day'] as num).toInt();
    final terminalDate = now.add(Duration(days: lastDay));

    // ── derive urgency + impact + insights with the same logic as the screen
    final urgency = _Urgency.from(timeline, startShort);
    final impact = _Impact.from(urgency, prices, batchKg);
    final insights = RecommendationEngine.generate(
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

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
        build: (ctx) => [
          _header(reportTs, place, leafAge, batchKg),
          pw.SizedBox(height: 14),
          _heroJourney(
              startShort, endShort, lastDay, terminalDate, urgency, money),
          pw.SizedBox(height: 12),
          _impactSection(impact, money, startShort, endShort),
          pw.SizedBox(height: 12),
          _trajectoryTable(timeline),
          pw.SizedBox(height: 12),
          if (insights.isNotEmpty) _insightsSection(insights),
          if (insights.isNotEmpty) pw.SizedBox(height: 12),
          _actionPlan(milestones, now),
          pw.SizedBox(height: 12),
          _fieldConditions(place, currentTemp, currentHum, currentRain),
          if (imgBytes != null) ...[
            pw.SizedBox(height: 12),
            _leafSample(imgBytes),
          ],
          pw.SizedBox(height: 14),
          _footer(reportTs),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header band ─────────────────────────────────────────────────────────
  static pw.Widget _header(
      String ts, String place, int leafAge, double batchKg) {
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
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Quality Forecast Report',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated $ts',
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
              _miniMeta('LOCATION', place),
              pw.SizedBox(height: 6),
              _miniMeta('LEAF AGE', '$leafAge d'),
              pw.SizedBox(height: 6),
              _miniMeta(
                  'BATCH',
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
            letterSpacing: 1.2,
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
          _sectionTitle('QUALITY TRAJECTORY', icon: '📈'),
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
                    'TERMINAL GRADE',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: _Palette.muted,
                      letterSpacing: 1.4,
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
                    urgency.level,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      letterSpacing: 1.3,
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
    _Impact impact,
    NumberFormat money,
    String fromTier,
    String toTier,
  ) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('ECONOMIC IMPACT', icon: 'Rs'),
          pw.SizedBox(height: 10),
          if (impact.showSavings) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRESERVE BY ACTING NOW',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: _Palette.muted,
                        letterSpacing: 1.4,
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
                      'TOTAL AT RISK',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: _Palette.muted,
                        letterSpacing: 1.4,
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
                _ratePill('NOW', fromTier, impact.currentValue, money),
                pw.SizedBox(width: 8),
                pw.Text('→',
                    style: pw.TextStyle(
                        color: _Palette.muted,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 8),
                _ratePill('IF WAITED', toTier, impact.projectedValue, money),
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
              letterSpacing: 1.4,
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
  static pw.Widget _trajectoryTable(List<dynamic> timeline) {
    final headerStyle = pw.TextStyle(
      fontSize: 8.5,
      color: _Palette.muted,
      letterSpacing: 1.1,
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = pw.TextStyle(fontSize: 9.5, color: _Palette.charcoal);

    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('15-DAY FORECAST'),
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
                  _cell('DAY', headerStyle, header: true),
                  _cell('DATE', headerStyle, header: true),
                  _cell('GRADE', headerStyle, header: true),
                  _cell('TEMP °C', headerStyle, header: true),
                  _cell('HUM %', headerStyle, header: true),
                  _cell('RAIN mm', headerStyle, header: true),
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

  // ── Expert recommendations ──────────────────────────────────────────────
  static pw.Widget _insightsSection(List<Recommendation> insights) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('EXPERT RECOMMENDATIONS',
              suffix: '${insights.length} insight${insights.length == 1 ? '' : 's'}'),
          pw.SizedBox(height: 8),
          ...insights.asMap().entries.map((e) {
            final isLast = e.key == insights.length - 1;
            return _insightRow(e.value, isLast);
          }),
        ],
      ),
    );
  }

  static pw.Widget _insightRow(Recommendation r, bool isLast) {
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
                    letterSpacing: 0.3,
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
                    RecPriority.high => 'HIGH',
                    RecPriority.medium => 'MED',
                    RecPriority.low => 'LOW',
                  },
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
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
              'Evidence: ${r.evidence!}',
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
  static pw.Widget _actionPlan(List<dynamic> milestones, DateTime now) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('HARVEST ACTION PLAN'),
          pw.SizedBox(height: 8),
          if (milestones.isEmpty)
            pw.Text(
              'Batch already at T4 — not suitable for premium-grade processing. Send for residual recovery only.',
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
                      ? 'today'
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
                        'before $when',
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
  static pw.Widget _fieldConditions(
      String place, String temp, String hum, String rain) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('CURRENT FIELD CONDITIONS', suffix: place),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _weatherStat('Temperature', temp,
                  const PdfColor.fromInt(0xFFD9534F)),
              pw.SizedBox(width: 8),
              _weatherStat(
                  'Humidity', hum, const PdfColor.fromInt(0xFF3B82F6)),
              pw.SizedBox(width: 8),
              _weatherStat(
                  'Rainfall', rain, const PdfColor.fromInt(0xFF6B7280)),
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
                letterSpacing: 1.2,
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
  static pw.Widget _leafSample(Uint8List imgBytes) {
    return _surfaceCard(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('LEAF SAMPLE'),
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
  static pw.Widget _footer(String ts) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _Palette.surface,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Generated by TeaOptima · Quality Forecast Engine',
            style: pw.TextStyle(
              fontSize: 8,
              color: _Palette.primary,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.6,
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
              letterSpacing: 1.4,
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
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static String _short(String t) =>
      RegExp(r'T[1-4]').firstMatch(t)?.group(0) ?? '—';
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

  static _Urgency from(List<dynamic> timeline, String startTier) {
    final startM = RegExp(r'T([1-4])').firstMatch(startTier);
    if (startM == null || timeline.isEmpty) {
      return const _Urgency(
        level: 'UNKNOWN',
        headline: 'INSUFFICIENT DATA',
        subline: 'Unable to compute harvest urgency.',
        gradient: [
          PdfColor.fromInt(0xFF4B5563),
          PdfColor.fromInt(0xFF6B7280),
        ],
      );
    }
    final startT = int.parse(startM.group(1)!);
    if (startT == 4) {
      return const _Urgency(
        level: 'PAST PRIME',
        headline: 'PROCESS IMMEDIATELY',
        subline: 'Leaf has reached T4. Send to factory today.',
        gradient: [
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
        headline: 'QUALITY HOLDING',
        subline:
            'Leaf projected to retain T$startT grade across the 15-day window.',
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
      headline = 'HARVEST TODAY';
      gradient = const [
        PdfColor.fromInt(0xFF7F1D1D),
        PdfColor.fromInt(0xFFEA580C),
      ];
    } else if (dropDay <= 3) {
      level = 'HIGH';
      headline = 'HARVEST WITHIN $dropDay DAYS';
      gradient = const [
        PdfColor.fromInt(0xFFB45309),
        PdfColor.fromInt(0xFFF59E0B),
      ];
    } else if (dropDay <= 7) {
      level = 'MODERATE';
      headline = 'PLAN HARVEST IN $dropDay DAYS';
      gradient = const [
        PdfColor.fromInt(0xFF166534),
        PdfColor.fromInt(0xFFEAB308),
      ];
    } else {
      level = 'COMFORTABLE';
      headline = '$dropDay-DAY HARVEST WINDOW';
      gradient = const [
        PdfColor.fromInt(0xFF064E3B),
        PdfColor.fromInt(0xFF22C55E),
      ];
    }
    final dayWord = dropDay == 1 ? 'day' : 'days';
    return _Urgency(
      level: level,
      headline: headline,
      subline:
          'Leaf grade is projected to drop from T$startT to $toTier in $dropDay $dayWord.',
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

  static _Impact from(
      _Urgency u, Map<String, double> prices, double batchKg) {
    final from = u.fromTier;
    final to = u.toTier ?? u.fromTier;
    final fromPrice = from == null ? 0.0 : (prices[from] ?? 0.0);
    final toPrice = to == null ? 0.0 : (prices[to] ?? 0.0);
    final perKg = (fromPrice - toPrice).clamp(0.0, double.infinity);
    final total = perKg * batchKg;
    final showSavings =
        u.level != 'STABLE' && u.level != 'PAST PRIME' && perKg > 0;
    final pitch = u.level == 'PAST PRIME'
        ? 'Batch already at minimum grade. Process today to lock in residual value.'
        : 'Quality projected to hold. Full batch value preserved across the window.';
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
