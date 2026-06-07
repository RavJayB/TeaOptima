// lib/widgets/price_ticker_banner.dart
//
// Seamless auto-scrolling "ticker" of indicative Colombo Auction tea prices,
// fed by Remote Config (with graceful fallback to PricingService defaults).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/pricing_service.dart';
import '../services/remote_config_service.dart';
import '../theme/tea_theme.dart';

class PriceTickerBanner extends StatefulWidget {
  const PriceTickerBanner({super.key});

  @override
  State<PriceTickerBanner> createState() => _PriceTickerBannerState();
}

class _PriceTickerBannerState extends State<PriceTickerBanner>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _copyKey = GlobalKey();
  Ticker? _ticker;
  double _offset = 0;
  double _copyWidth = 0;
  static const double _gap = 28;
  static const double _speed = 0.45; // px/frame (~27 px/s @60fps)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _copyWidth = _copyKey.currentContext?.size?.width ?? 0;
      _ticker = createTicker(_tick)..start();
    });
  }

  void _tick(Duration _) {
    if (!_scroll.hasClients || _copyWidth <= 0) return;
    _offset += _speed;
    final period = _copyWidth + _gap;
    if (_offset >= period) _offset -= period; // seamless: shift by one copy
    _scroll.jumpTo(_offset);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prices = PricingService.indicativePrices();
    final week = RemoteConfigService.weekLabel;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: TeaTheme.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Row(
                key: _copyKey,
                mainAxisSize: MainAxisSize.min,
                children: _content(l, prices, week),
              ),
              const SizedBox(width: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _content(l, prices, week), // 2nd copy → seamless loop
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
      AppLocalizations l, Map<String, double> prices, String week) {
    final items = <Widget>[
      const Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
      const SizedBox(width: 7),
      Text(
        '${l.bannerAuctionRates} · ${l.bannerIndicative}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      const SizedBox(width: 14),
    ];
    for (final t in const ['T1', 'T2', 'T3', 'T4']) {
      items.add(_chip('${l.tierWord} ${t.substring(1)}', prices[t] ?? 0));
      items.add(const SizedBox(width: 10));
    }
    if (week.isNotEmpty) {
      items.add(Text(
        '· $week',
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
      ));
      items.add(const SizedBox(width: 10));
    }
    return items;
  }

  Widget _chip(String label, double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Rs ${price.toStringAsFixed(0)}/kg',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
