// lib/services/pricing_service.dart
//
// Persists user-editable Rs/kg tea prices per quality tier and the
// preferred batch size. Defaults are indicative Colombo Tea Auction
// averages (late 2024 / early 2025) — farmers can override per their
// own factory's purchase rate.
//
// Storage: SharedPreferences (device-local). Multi-user / factory-wide
// sync can be layered on later via Firestore if needed.

import 'package:shared_preferences/shared_preferences.dart';

class PricingService {
  // Defaults — indicative Colombo Tea Auction net sale averages (LKR/kg).
  // Farmers can edit these in-app.
  static const Map<String, double> defaultPrices = {
    'T1': 950.0, // Premium / Select
    'T2': 800.0, // Good
    'T3': 650.0, // Average
    'T4': 400.0, // Poor / Refuse
  };

  static const double defaultBatchKg = 50.0;

  static const _kPriceT1 = 'price_t1';
  static const _kPriceT2 = 'price_t2';
  static const _kPriceT3 = 'price_t3';
  static const _kPriceT4 = 'price_t4';
  static const _kBatchKg = 'batch_kg';

  static String _key(String tier) {
    switch (tier) {
      case 'T1':
        return _kPriceT1;
      case 'T2':
        return _kPriceT2;
      case 'T3':
        return _kPriceT3;
      case 'T4':
        return _kPriceT4;
      default:
        throw ArgumentError('Unknown tier: $tier');
    }
  }

  static Future<Map<String, double>> loadPrices() async {
    final p = await SharedPreferences.getInstance();
    return {
      for (final t in defaultPrices.keys)
        t: p.getDouble(_key(t)) ?? defaultPrices[t]!,
    };
  }

  static Future<void> savePrices(Map<String, double> prices) async {
    final p = await SharedPreferences.getInstance();
    for (final entry in prices.entries) {
      await p.setDouble(_key(entry.key), entry.value);
    }
  }

  static Future<void> resetToDefaults() async {
    final p = await SharedPreferences.getInstance();
    for (final t in defaultPrices.keys) {
      await p.remove(_key(t));
    }
  }

  static Future<double> loadBatchKg() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_kBatchKg) ?? defaultBatchKg;
  }

  static Future<void> saveBatchKg(double kg) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kBatchKg, kg);
  }
}
