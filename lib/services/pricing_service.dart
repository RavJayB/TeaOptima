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

import 'remote_config_service.dart';

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

  // Alongside each override we store the auction price it was made against
  // ("baseline"). A grower's edit only holds while the auction price is
  // unchanged; once the admin publishes a NEW price, the baseline no longer
  // matches and the override is dropped so the new auction price shows.
  static String _baseKey(String tier) => '${_key(tier)}_base';

  /// Indicative prices for display (banner): remote → hardcoded. Ignores any
  /// per-grower override — the banner always shows the admin's auction prices.
  static Map<String, double> indicativePrices() => {
        for (final t in defaultPrices.keys)
          t: RemoteConfigService.remotePrice(t) ?? defaultPrices[t]!,
      };

  /// Effective prices for the factory card + economic impact.
  /// A grower's override applies ONLY while the auction price it was made
  /// against is still current; if the admin has since published a new price,
  /// the stale override is discarded and the new auction price is used.
  static Future<Map<String, double>> loadPrices() async {
    final p = await SharedPreferences.getInstance();
    final indicative = indicativePrices();
    final out = <String, double>{};
    for (final t in defaultPrices.keys) {
      final ind = indicative[t]!;
      final override = p.getDouble(_key(t));
      final base = p.getDouble(_baseKey(t));
      if (override != null && base != null && (base - ind).abs() < 0.5) {
        out[t] = override; // grower's edit, auction price unchanged → keep it
      } else {
        if (override != null) {
          // No baseline match → auction price changed → drop the stale override.
          await p.remove(_key(t));
          await p.remove(_baseKey(t));
        }
        out[t] = ind; // follow the latest auction price
      }
    }
    return out;
  }

  /// Persist prices. A tier is pinned as a grower override only when it differs
  /// from the current auction price; we also record the auction price it was
  /// made against so it can be auto-released on the next price publish.
  static Future<void> savePrices(Map<String, double> prices) async {
    final p = await SharedPreferences.getInstance();
    final indicative = indicativePrices();
    for (final entry in prices.entries) {
      final t = entry.key;
      final ind = indicative[t] ?? defaultPrices[t]!;
      if ((entry.value - ind).abs() < 0.5) {
        await p.remove(_key(t)); // matches auction → follow remote
        await p.remove(_baseKey(t));
      } else {
        await p.setDouble(_key(t), entry.value); // grower override
        await p.setDouble(_baseKey(t), ind); // ...against this auction price
      }
    }
  }

  static Future<void> resetToDefaults() async {
    final p = await SharedPreferences.getInstance();
    for (final t in defaultPrices.keys) {
      await p.remove(_key(t));
      await p.remove(_baseKey(t));
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
