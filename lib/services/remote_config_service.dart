// lib/services/remote_config_service.dart
//
// Central, remotely-updatable indicative tea prices (Colombo Auction averages)
// via Firebase Remote Config. You publish the weekly averages once in the
// Firebase console and every app picks them up — no release needed.
//
// Keys (set these in Firebase Console → Remote Config):
//   price_t1, price_t2, price_t3, price_t4   (Number, Rs/kg)
//   price_week_label                         (String, e.g. "Week of 2 Jun 2026")
//
// Everything degrades gracefully: offline or unconfigured → returns null and
// callers fall back to PricingService.defaultPrices.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _rc;

  // In-app defaults so the banner shows sensible values before/without a fetch.
  static final Map<String, dynamic> _defaults = {
    'price_t1': 950.0,
    'price_t2': 800.0,
    'price_t3': 650.0,
    'price_t4': 400.0,
    'price_week_label': '',
  };

  /// Fetch + activate Remote Config. Safe to call once at startup; never throws.
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 6),
        // Instant updates while developing; throttled in release to save quota.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 6),
      ));
      await rc.setDefaults(_defaults);
      await rc.fetchAndActivate();
      _rc = rc;
    } catch (_) {
      // Offline / not configured / Remote Config unavailable — fall back.
    }
  }

  /// Latest indicative price for a tier ('T1'..'T4'), or null if unavailable.
  static double? remotePrice(String tier) {
    final rc = _rc;
    if (rc == null) return null;
    final v = rc.getDouble('price_${tier.toLowerCase()}');
    return v > 0 ? v : null;
  }

  /// Optional label describing the price vintage (e.g. "Week of 2 Jun 2026").
  static String get weekLabel => _rc?.getString('price_week_label') ?? '';
}
