// lib/services/recommendation_engine.dart
//
// Rule-based expert system that turns the raw 15-day forecast + leaf state
// + saved Rs/kg prices into a short, prioritised list of recommendations
// for the result screen.
//
// Rules are deterministic (judge-demo friendly, offline-capable, free).
// Each rule produces zero or one `Recommendation`; the final list is sorted
// by priority and capped.
//
// Tea-domain heuristics (Sri Lankan plantation context):
//   • 2-leaves-and-bud plucking standard
//   • Early-morning plucking on hot days to avoid wilt
//   • Wet leaf bruising during transport / withering mould risk
//   • Sustained humidity accelerates field-fermentation
//   • OP / BOPF orthodox = premium grades; CTC = bulk processing

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum RecPriority { high, medium, low }

enum RecCategory { timing, weather, quality, economic, technique }

class Recommendation {
  final String title;
  final String detail;
  final String? evidence;
  final RecPriority priority;
  final RecCategory category;
  final IconData icon;
  final Color accent;

  const Recommendation({
    required this.title,
    required this.detail,
    required this.priority,
    required this.category,
    required this.icon,
    required this.accent,
    this.evidence,
  });

  int get priorityRank => switch (priority) {
        RecPriority.high => 3,
        RecPriority.medium => 2,
        RecPriority.low => 1,
      };
}

class RecommendationEngine {
  static const int _maxRecs = 5;

  static List<Recommendation> generate({
    required AppLocalizations l,
    required List<dynamic> timeline,
    required List<dynamic> milestones,
    required String startingQuality,
    required int leafAge,
    required Map<String, double> prices,
    required double batchKg,
  }) {
    final recs = <Recommendation>[];
    if (timeline.isEmpty) return recs;

    final startT = _parseTier(startingQuality);
    final drop = _findFirstDrop(timeline, startT);

    // ── Rule 1: Timing — first grade drop dictates the window
    if (drop != null) {
      final RecPriority pri;
      final String title;
      final String detail;
      if (drop.dropDay == 1) {
        pri = RecPriority.high;
        title = l.recTimingTodayTitle;
        detail = l.recTimingTodayDetail(drop.fromT, drop.toT);
      } else if (drop.dropDay <= 3) {
        pri = RecPriority.high;
        title = l.urgHeadWithin(drop.dropDay);
        detail = l.recTimingSoonDetail(drop.fromT, drop.toT, drop.dropDay);
      } else if (drop.dropDay <= 7) {
        pri = RecPriority.medium;
        title = l.urgHeadPlan(drop.dropDay);
        detail = l.recTimingPlanDetail(drop.dropDay);
      } else {
        pri = RecPriority.low;
        title = l.recTimingComfortTitle;
        detail = l.recTimingComfortDetail(drop.dropDay);
      }
      recs.add(Recommendation(
        title: title,
        detail: detail,
        evidence: l.recTimingEvidence(drop.dropDay),
        priority: pri,
        category: RecCategory.timing,
        icon: Icons.schedule_rounded,
        accent: const Color(0xFF1B5E3F),
      ));
    } else if (startT == 4) {
      recs.add(Recommendation(
        title: l.recPastPrimeTitle,
        detail: l.recPastPrimeDetail,
        evidence: l.recPastPrimeEvidence,
        priority: RecPriority.high,
        category: RecCategory.timing,
        icon: Icons.gpp_bad_rounded,
        accent: const Color(0xFFA04823),
      ));
    }

    // ── Rule 2: Heat stress (consecutive days above 30 °C)
    final heat = _findHeatRun(timeline, 30.0);
    if (heat != null && heat.length >= 2) {
      recs.add(Recommendation(
        title: l.recHeatTitle,
        detail: l.recHeatDetail(heat.length, heat.startDay, heat.endDay),
        evidence: l.recHeatEvidence(
            heat.avg.toStringAsFixed(1), heat.startDay, heat.endDay),
        priority: heat.length >= 4 ? RecPriority.high : RecPriority.medium,
        category: RecCategory.weather,
        icon: Icons.local_fire_department_rounded,
        accent: const Color(0xFFD9534F),
      ));
    }

    // ── Rule 3: Rainfall spike (>10 mm any single day)
    final rain = _findRainSpike(timeline, 10.0);
    if (rain != null) {
      recs.add(Recommendation(
        title: l.recRainTitle(rain.day),
        detail: l.recRainDetail(rain.mm.toStringAsFixed(1)),
        evidence: l.recRainEvidence(rain.mm.toStringAsFixed(1), rain.day),
        priority: rain.mm >= 20 ? RecPriority.high : RecPriority.medium,
        category: RecCategory.weather,
        icon: Icons.umbrella_rounded,
        accent: const Color(0xFF3B82F6),
      ));
    }

    // ── Rule 4: Sustained high humidity (>80 % for 3+ days)
    final hum = _findSustainedHumidity(timeline, 80.0, 3);
    if (hum != null) {
      recs.add(Recommendation(
        title: l.recHumTitle,
        detail: l.recHumDetail(hum.avg.toStringAsFixed(0), hum.days),
        evidence: l.recHumEvidence(hum.avg.toStringAsFixed(0), hum.days),
        priority: RecPriority.medium,
        category: RecCategory.weather,
        icon: Icons.water_drop_rounded,
        accent: const Color(0xFF6366F1),
      ));
    }

    // ── Rule 5: Leaf-age maturity (only the strong end of the spectrum)
    if (leafAge >= 6) {
      recs.add(Recommendation(
        title: l.recMatureTitle,
        detail: l.recMatureDetail(leafAge),
        evidence: l.recMatureEvidence(leafAge),
        priority: RecPriority.low,
        category: RecCategory.quality,
        icon: Icons.eco_rounded,
        accent: const Color(0xFFB8843A),
      ));
    } else if (leafAge <= 2 && startT <= 2) {
      recs.add(Recommendation(
        title: l.recYoungTitle,
        detail: l.recYoungDetail(leafAge, startT),
        evidence: l.recYoungEvidence(leafAge, startT),
        priority: RecPriority.low,
        category: RecCategory.quality,
        icon: Icons.spa_rounded,
        accent: const Color(0xFF1B5E3F),
      ));
    }

    // ── Rule 6: Plucking standard (only when at premium grades)
    if (startT == 1 || startT == 2) {
      recs.add(Recommendation(
        title: l.recTechniqueTitle,
        detail: l.recTechniqueDetail(startT),
        evidence: l.recTechniqueEvidence(startT),
        priority: RecPriority.low,
        category: RecCategory.technique,
        icon: Icons.task_alt_rounded,
        accent: const Color(0xFF2E7D5B),
      ));
    }

    // ── Rule 7: Economic upside callout (only when a drop is imminent)
    if (drop != null) {
      final fromKey = 'T${drop.fromT}';
      final toKey = 'T${drop.toT}';
      final fromPrice = prices[fromKey] ?? 0;
      final toPrice = prices[toKey] ?? 0;
      final delta = fromPrice - toPrice;
      if (delta > 0 && batchKg > 0) {
        final total = delta * batchKg;
        final batchStr = batchKg.toStringAsFixed(batchKg % 1 == 0 ? 0 : 1);
        recs.add(Recommendation(
          title: l.recEconTitle(total.toStringAsFixed(0)),
          detail: l.recEconDetail(
              delta.toStringAsFixed(0), batchStr, total.toStringAsFixed(0)),
          evidence: l.recEconEvidence(fromKey, fromPrice.toStringAsFixed(0),
              toKey, toPrice.toStringAsFixed(0)),
          priority: drop.dropDay <= 3 ? RecPriority.high : RecPriority.medium,
          category: RecCategory.economic,
          icon: Icons.payments_rounded,
          accent: const Color(0xFFD4A82C),
        ));
      }
    }

    recs.sort((a, b) => b.priorityRank.compareTo(a.priorityRank));
    return recs.take(_maxRecs).toList();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  static int _parseTier(String raw) {
    final m = RegExp(r'T([1-4])').firstMatch(raw);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  static ({int dropDay, int fromT, int toT})? _findFirstDrop(
      List<dynamic> timeline, int startT) {
    if (startT == 0 || startT == 4) return null;
    int prevScore = 5 - startT;
    for (final t in timeline) {
      final pq = (t['pred_q'] as num).toInt();
      if (pq < prevScore) {
        return (
          dropDay: (t['day'] as num).toInt(),
          fromT: 5 - prevScore,
          toT: 5 - pq,
        );
      }
      prevScore = pq;
    }
    return null;
  }

  static ({int startDay, int endDay, int length, double avg})? _findHeatRun(
      List<dynamic> timeline, double threshold) {
    int? bestStart, bestEnd;
    int bestLen = 0;
    double bestSum = 0;

    int curStart = -1;
    int curLen = 0;
    double curSum = 0;

    void commit() {
      if (curLen > bestLen) {
        bestLen = curLen;
        bestStart = curStart;
        bestEnd = curStart + curLen - 1;
        bestSum = curSum;
      }
    }

    for (final t in timeline) {
      final temp = (t['temp'] as num).toDouble();
      final day = (t['day'] as num).toInt();
      if (temp > threshold) {
        if (curStart < 0) curStart = day;
        curLen++;
        curSum += temp;
      } else {
        commit();
        curStart = -1;
        curLen = 0;
        curSum = 0;
      }
    }
    commit();

    if (bestStart == null || bestLen < 1) return null;
    return (
      startDay: bestStart!,
      endDay: bestEnd!,
      length: bestLen,
      avg: bestSum / bestLen,
    );
  }

  static ({int day, double mm})? _findRainSpike(
      List<dynamic> timeline, double threshold) {
    double max = 0;
    int maxDay = 0;
    for (final t in timeline) {
      final r = (t['rain'] as num).toDouble();
      if (r > max) {
        max = r;
        maxDay = (t['day'] as num).toInt();
      }
    }
    if (max < threshold) return null;
    return (day: maxDay, mm: max);
  }

  static ({int days, double avg})? _findSustainedHumidity(
      List<dynamic> timeline, double threshold, int minDays) {
    int bestCount = 0;
    double bestSum = 0;
    int curCount = 0;
    double curSum = 0;
    for (final t in timeline) {
      final h = (t['hum'] as num).toDouble();
      if (h > threshold) {
        curCount++;
        curSum += h;
        if (curCount > bestCount) {
          bestCount = curCount;
          bestSum = curSum;
        }
      } else {
        curCount = 0;
        curSum = 0;
      }
    }
    if (bestCount < minDays) return null;
    return (days: bestCount, avg: bestSum / bestCount);
  }
}
