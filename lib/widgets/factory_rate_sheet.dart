// lib/widgets/factory_rate_sheet.dart
//
// Reusable "Factory Rate Card" bottom sheet — edits the user's Rs/kg tea
// prices per quality tier plus the default batch size. Backed by
// PricingService (device-local). Shared by Profile settings and (optionally)
// the result screen so the pricing UI lives in one place.

import 'package:flutter/material.dart';

import '../services/pricing_service.dart';
import '../theme/tea_theme.dart';

/// Opens the Factory Rate Card editor. Returns true if the user saved changes.
Future<bool> showFactoryRateSheet(BuildContext context) async {
  final prices = await PricingService.loadPrices();
  final batch = await PricingService.loadBatchKg();
  if (!context.mounted) return false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FactoryRateSheet(initialPrices: prices, initialBatch: batch),
  );
  return saved ?? false;
}

class _FactoryRateSheet extends StatefulWidget {
  final Map<String, double> initialPrices;
  final double initialBatch;
  const _FactoryRateSheet({
    required this.initialPrices,
    required this.initialBatch,
  });

  @override
  State<_FactoryRateSheet> createState() => _FactoryRateSheetState();
}

class _FactoryRateSheetState extends State<_FactoryRateSheet> {
  late final Map<String, TextEditingController> _priceCtrls;
  late final TextEditingController _batchCtrl;

  static const _meta = {
    'T1': ('Highest Quality', 'Premium / Select'),
    'T2': ('Good Quality', 'Standard plucking'),
    'T3': ('Average Quality', 'Coarse / older leaf'),
    'T4': ('Poor Quality', 'Refuse / over-mature'),
  };

  @override
  void initState() {
    super.initState();
    _priceCtrls = {
      for (final t in ['T1', 'T2', 'T3', 'T4'])
        t: TextEditingController(
          text: (widget.initialPrices[t] ?? PricingService.defaultPrices[t]!)
              .toStringAsFixed(0),
        ),
    };
    _batchCtrl = TextEditingController(
      text: widget.initialBatch
          .toStringAsFixed(widget.initialBatch % 1 == 0 ? 0 : 1),
    );
  }

  @override
  void dispose() {
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    _batchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPrices = <String, double>{};
    for (final t in ['T1', 'T2', 'T3', 'T4']) {
      final v = double.tryParse(_priceCtrls[t]!.text) ??
          PricingService.defaultPrices[t]!;
      newPrices[t] = v.clamp(0.0, 100000.0);
    }
    final batch =
        (double.tryParse(_batchCtrl.text) ?? PricingService.defaultBatchKg)
            .clamp(0.1, 100000.0);
    await PricingService.savePrices(newPrices);
    await PricingService.saveBatchKg(batch);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    await PricingService.resetToDefaults();
    for (final t in ['T1', 'T2', 'T3', 'T4']) {
      _priceCtrls[t]!.text = PricingService.defaultPrices[t]!.toStringAsFixed(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TeaTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_florist_rounded,
                          color: TeaTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Factory Rate Card',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: TeaTheme.deep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set Rs/kg per tier — defaults are Colombo Auction averages.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
                    child: _priceField(tier),
                  ),
                const SizedBox(height: 6),
                // batch size
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TeaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: TeaTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.scale_rounded,
                            color: TeaTheme.primary, size: 21),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Default Batch Size',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text('Used for economic estimates',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _batchCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: 'kg',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: TeaTheme.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save Rates'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TeaTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
  }

  Widget _priceField(String tier) {
    final accent = TeaTheme.tier(tier);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TeaTheme.border),
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
                Text(_meta[tier]!.$1,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(_meta[tier]!.$2,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: TextField(
              controller: _priceCtrls[tier],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                prefixText: 'Rs ',
                suffixText: '/kg',
                suffixStyle:
                    TextStyle(color: Colors.grey.shade500, fontSize: 11),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
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
}
