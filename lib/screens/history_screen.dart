// lib/screens/history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../theme/tea_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final stream = FirebaseFirestore.instance
        .collection('simulations')
        .where('userId', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: TeaTheme.primary),
                );
              }
              final docs = snap.data?.docs ?? [];
              final stats = _HistoryStats.from(docs);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(l, stats)),
                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(l),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _dashboard(l, stats)),
                    SliverToBoxAdapter(child: _sectionLabel(l, docs.length)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _historyCard(context, l, docs[i]),
                          childCount: docs.length,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Hero header ───────────────────────────────────────────────────────────
  Widget _header(AppLocalizations l, _HistoryStats s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
        ),
        boxShadow: [
          BoxShadow(
            color: TeaTheme.primary.withOpacity(0.32),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(Icons.eco_rounded,
                size: 120, color: Colors.white.withOpacity(0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.30)),
                    ),
                    child: const Icon(Icons.insights_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l.histHeaderLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                s.total == 0 ? l.histNoScans : l.histScansLogged(s.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.total == 0
                    ? l.histSubEmpty
                    : l.histSubActive,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dashboard (stats + quality profile + urgency) ──────────────────────────
  Widget _dashboard(AppLocalizations l, _HistoryStats s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          // ── stat tiles row
          Row(
            children: [
              _statTile(
                icon: Icons.eco_rounded,
                value: '${s.total}',
                label: l.histTotalScans,
                accent: TeaTheme.primary,
              ),
              const SizedBox(width: 10),
              _statTile(
                icon: Icons.calendar_today_rounded,
                value: '${s.thisWeek}',
                label: l.histThisWeek,
                accent: TeaTheme.mid,
              ),
              const SizedBox(width: 10),
              _statTile(
                icon: Icons.bolt_rounded,
                value: '${s.urgent}',
                label: l.histUrgent,
                accent: const Color(0xFFD9534F),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── quality profile
          _qualityProfile(l, s),
          const SizedBox(height: 12),
          // ── estate insight strip
          _insightStrip(l, s),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: TeaTheme.card(),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: TeaTheme.deep,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityProfile(AppLocalizations l, _HistoryStats s) {
    final maxCount =
        s.dist.values.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 1 << 30);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: TeaTheme.card(),
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
                child: const Icon(Icons.workspace_premium_rounded,
                    color: TeaTheme.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                l.histQualityProfile,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TeaTheme.deep,
                ),
              ),
              const Spacer(),
              if (s.topGrade != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: TeaTheme.tier(s.topGrade!).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.histMostly(s.topGrade!),
                    style: TextStyle(
                      color: TeaTheme.tier(s.topGrade!),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...['T1', 'T2', 'T3', 'T4'].map((t) {
            final count = s.dist[t] ?? 0;
            final frac = count / maxCount;
            final pct = s.total == 0 ? 0 : (count / s.total * 100).round();
            final c = TeaTheme.tier(t);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      t,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        color: c,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: TeaTheme.surface,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: frac == 0 ? 0.001 : frac,
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c, c.withOpacity(0.75)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 58,
                    child: Text(
                      count == 0 ? '–' : '$count ($pct%)',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _insightStrip(AppLocalizations l, _HistoryStats s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: TeaTheme.card(),
      child: Row(
        children: [
          Expanded(
            child: _insightItem(
              icon: Icons.location_on_rounded,
              label: l.histTopEstate,
              value: s.topLocation,
              accent: TeaTheme.primary,
            ),
          ),
          Container(width: 1, height: 34, color: TeaTheme.border),
          Expanded(
            child: _insightItem(
              icon: Icons.spa_rounded,
              label: l.histAvgLeafAge,
              value: s.avgLeafAge == 0
                  ? '–'
                  : '${s.avgLeafAge.toStringAsFixed(1)} ${l.histDayShort}',
              accent: TeaTheme.mid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightItem({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: TeaTheme.deep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(AppLocalizations l, int n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Text(
            l.histRecentPredictions,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TeaTheme.deep,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l.histSwipeToDelete,
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ── History card ────────────────────────────────────────────────────────
  Widget _historyCard(
      BuildContext context, AppLocalizations l, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tier = TeaTheme.tierShort((data['starting_quality'] ?? '').toString());
    final c = TeaTheme.tier(tier);
    final leafAge = data['leaf_age'] ?? '–';
    final location = (data['location'] ?? 'Unknown').toString();
    final date = _formatDate(l, data['created_at'] as Timestamp?);
    final level = _HistoryStats.urgency(data);
    final t4 = _HistoryStats.t4Date(data);
    final hasImage = (data['image_url'] is String) &&
        (data['image_url'] as String).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(doc.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: const Color(0xFFD9534F),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 24),
        ),
        confirmDismiss: (_) => _confirmDelete(l, context),
        onDismissed: (_) async {
          await doc.reference.delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.histPredictionDeleted),
                behavior: SnackBarBehavior.floating,
                backgroundColor: TeaTheme.deep,
              ),
            );
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showDetail(context, l, data),
            child: Container(
              decoration: TeaTheme.card().copyWith(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // tier badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c, c.withOpacity(0.78)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: c.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tier,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                        Text(
                          TeaTheme.tierName(tier),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l.histLeafAgeShort('$leafAge'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: TeaTheme.deep,
                              ),
                            ),
                            if (level != UrgencyLevel.stable) ...[
                              const SizedBox(width: 8),
                              _urgencyBadge(l, level),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Icon(Icons.schedule_rounded,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        _deadlineLine(l, level, t4),
                      ],
                    ),
                  ),
                  // trailing
                  Column(
                    children: [
                      if (hasImage)
                        Icon(Icons.image_rounded,
                            size: 16, color: TeaTheme.mid.withOpacity(0.7)),
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Urgency UI helpers ────────────────────────────────────────────────────
  static Color _urgencyColor(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.pastPrime:
        return const Color(0xFFD9534F);
      case UrgencyLevel.urgent:
        return const Color(0xFFD9534F);
      case UrgencyLevel.soon:
        return const Color(0xFFB45309);
      case UrgencyLevel.stable:
        return TeaTheme.mid;
    }
  }

  static String _urgencyLabel(AppLocalizations l, UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.pastPrime:
        return l.histUrgencyPastPrime;
      case UrgencyLevel.urgent:
        return l.histUrgencyUrgent;
      case UrgencyLevel.soon:
        return l.histUrgencySoon;
      case UrgencyLevel.stable:
        return l.histUrgencyStable;
    }
  }

  Widget _urgencyBadge(AppLocalizations l, UrgencyLevel level) {
    final c = _urgencyColor(level);
    final label = _urgencyLabel(l, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _deadlineLine(AppLocalizations l, UrgencyLevel level, DateTime? t4) {
    if (t4 == null) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 13, color: TeaTheme.mid),
          const SizedBox(width: 4),
          Text(
            l.histStaysAboveT4,
            style: const TextStyle(
              fontSize: 11.5,
              color: TeaTheme.mid,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    final c = _urgencyColor(level);
    final text = level == UrgencyLevel.pastPrime
        ? l.histAlreadyT4Process
        : l.histUnprocessableBy(DateFormat('d MMM yyyy').format(t4));
    return Row(
      children: [
        Icon(Icons.hourglass_bottom_rounded, size: 13, color: c),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _t4Banner(AppLocalizations l, Map<String, dynamic> data) {
    final level = _HistoryStats.urgency(data);
    final t4 = _HistoryStats.t4Date(data);
    final c = _urgencyColor(level);
    final stable = t4 == null;
    final accent = stable ? TeaTheme.primary : c;
    final title = stable
        ? l.histT4StaysTitle
        : (level == UrgencyLevel.pastPrime
            ? l.histT4AlreadyTitle
            : l.histT4ReachesTitle);
    final sub = stable
        ? l.histT4StaysSub
        : (level == UrgencyLevel.pastPrime
            ? l.histT4AlreadySub
            : l.histT4ProcessBefore(DateFormat('EEEE, d MMM yyyy').format(t4)));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              stable
                  ? Icons.verified_rounded
                  : Icons.hourglass_bottom_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TeaTheme.deep,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────
  void _showDetail(
      BuildContext context, AppLocalizations l, Map<String, dynamic> data) {
    final tier = TeaTheme.tierShort((data['starting_quality'] ?? '').toString());
    final timeline = List<dynamic>.from(data['timeline'] ?? []);
    final endTier = timeline.isNotEmpty
        ? TeaTheme.tierShort((timeline.last['tier'] ?? '').toString())
        : tier;
    final weather = Map<String, dynamic>.from(data['weather'] ?? {});
    final leafAge = data['leaf_age'] ?? '–';
    final location = (data['location'] ?? 'Unknown').toString();
    final date = _formatDate(l, data['created_at'] as Timestamp?);
    final imageUrl = data['image_url'];
    final hasImage = imageUrl is String && imageUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: TeaTheme.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // tier journey
                Row(
                  children: [
                    _detailTierBadge(tier),
                    const SizedBox(width: 8),
                    Icon(
                      tier == endTier
                          ? Icons.horizontal_rule_rounded
                          : Icons.trending_down_rounded,
                      color: tier == endTier ? TeaTheme.mid : const Color(0xFFB8843A),
                    ),
                    const SizedBox(width: 8),
                    _detailTierBadge(endTier),
                    const Spacer(),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // when this batch becomes unprocessable (T4)
                _t4Banner(l, data),
                const SizedBox(height: 14),
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : Container(
                              height: 180,
                              alignment: Alignment.center,
                              color: TeaTheme.surface,
                              child: const CircularProgressIndicator(
                                  color: TeaTheme.primary),
                            ),
                      errorBuilder: (c, e, s) => Container(
                        height: 100,
                        alignment: Alignment.center,
                        color: TeaTheme.surface,
                        child: Text(l.histImageUnavailable,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // facts grid
                Row(
                  children: [
                    _detailFact(
                        Icons.location_on_rounded, l.histLocation, location),
                    _detailFact(Icons.spa_rounded, l.captureLeafAge,
                        l.histLeafAgeDaysFull('$leafAge')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _detailFact(Icons.thermostat_rounded, l.homeTemp,
                        _wx(weather['temp'], '°C')),
                    _detailFact(Icons.water_drop_rounded, l.homeHumidity,
                        _wx(weather['hum'], '%')),
                    _detailFact(Icons.umbrella_rounded, l.homeRain,
                        _wx(weather['rain'], 'mm')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeaTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.commonClose,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailTierBadge(String tier) {
    final c = TeaTheme.tier(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, c.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$tier · ${TeaTheme.tierName(tier)}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _detailFact(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: TeaTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: TeaTheme.mid),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: TeaTheme.deep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: TeaTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  size: 44, color: TeaTheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              l.histNoPredictions,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: TeaTheme.deep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.histEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  static String _formatDate(AppLocalizations l, Timestamp? ts) => ts == null
      ? l.histJustNow
      : DateFormat('d MMM yyyy, h:mm a').format(ts.toDate());

  static String _wx(dynamic v, String unit) {
    if (v == null) return '–';
    final s = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    final n = double.tryParse(s);
    if (n == null) return v.toString();
    return '${n.toStringAsFixed(unit == '%' ? 0 : 1)}$unit';
  }

  Future<bool> _confirmDelete(AppLocalizations l, BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l.histDeleteTitle),
        content: Text(l.histDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9534F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

// ── Urgency: based on how soon a batch becomes unprocessable (reaches T4) ────
enum UrgencyLevel { pastPrime, urgent, soon, stable }

// ── Analytics model ──────────────────────────────────────────────────────────
class _HistoryStats {
  final int total;
  final int thisWeek;
  final int urgent;
  final Map<String, int> dist;
  final String topLocation;
  final double avgLeafAge;
  final String? topGrade;

  _HistoryStats({
    required this.total,
    required this.thisWeek,
    required this.urgent,
    required this.dist,
    required this.topLocation,
    required this.avgLeafAge,
    required this.topGrade,
  });

  factory _HistoryStats.from(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    int thisWeek = 0, urgent = 0, ageSum = 0, ageN = 0;
    final dist = {'T1': 0, 'T2': 0, 'T3': 0, 'T4': 0};
    final locCount = <String, int>{};

    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final q = TeaTheme.tierShort((data['starting_quality'] ?? '').toString());
      if (dist.containsKey(q)) dist[q] = dist[q]! + 1;

      final ts = data['created_at'];
      if (ts is Timestamp && now.difference(ts.toDate()).inDays < 7) thisWeek++;

      final u = urgency(data);
      if (u == UrgencyLevel.urgent || u == UrgencyLevel.pastPrime) urgent++;

      final loc = (data['location'] ?? 'Unknown').toString();
      if (loc.isNotEmpty && loc != 'Fetching…') {
        locCount[loc] = (locCount[loc] ?? 0) + 1;
      }

      final age = data['leaf_age'];
      if (age is num) {
        ageSum += age.toInt();
        ageN++;
      }
    }

    final topLoc = locCount.isEmpty
        ? '–'
        : locCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final topGrade = dist.values.every((v) => v == 0)
        ? null
        : dist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _HistoryStats(
      total: docs.length,
      thisWeek: thisWeek,
      urgent: urgent,
      dist: dist,
      topLocation: topLoc,
      avgLeafAge: ageN > 0 ? ageSum / ageN : 0,
      topGrade: topGrade,
    );
  }

  /// Day-number at which the batch is forecast to reach T4 (unprocessable),
  /// or null if it stays above T4 across the whole forecast window.
  static int? daysToT4(Map<String, dynamic> data) {
    final q = TeaTheme.tierShort((data['starting_quality'] ?? '').toString());
    if (q == 'T4') return 0;
    final timeline = List<dynamic>.from(data['timeline'] ?? []);
    for (final t in timeline) {
      if (t is Map && t['pred_q'] is num && (t['pred_q'] as num).toInt() == 1) {
        return (t['day'] is num) ? (t['day'] as num).toInt() : null;
      }
    }
    return null;
  }

  /// Calendar date the batch reaches T4, relative to when it was scanned.
  static DateTime? t4Date(Map<String, dynamic> data) {
    final d = daysToT4(data);
    if (d == null) return null;
    final ts = data['created_at'];
    final base = (ts is Timestamp) ? ts.toDate() : DateTime.now();
    return base.add(Duration(days: d));
  }

  /// Urgency tier — how soon the batch becomes unprocessable.
  static UrgencyLevel urgency(Map<String, dynamic> data) {
    final d = daysToT4(data);
    if (d == null) return UrgencyLevel.stable;
    if (d == 0) return UrgencyLevel.pastPrime;
    if (d <= 3) return UrgencyLevel.urgent;
    if (d <= 7) return UrgencyLevel.soon;
    return UrgencyLevel.stable;
  }
}
