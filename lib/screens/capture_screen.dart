// lib/screens/capture_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../theme/tea_theme.dart';
import 'loading_screen.dart';

class CaptureScreen extends StatefulWidget {
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  File? _imageFile;
  String? _base64Image;
  int? _qualityScore;
  String? _qualityLabel;
  int _leafAge = 1;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  String _tDesc(AppLocalizations l, String t) {
    switch (t) {
      case 'T1':
        return l.tierHighest;
      case 'T2':
        return l.tierGood;
      case 'T3':
        return l.tierAverage;
      case 'T4':
        return l.tierPoor;
      default:
        return '';
    }
  }

  bool get _isReady => _qualityScore != null && _base64Image != null;

  // ─── Image pick / classify ────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    final picked = await _picker.pickImage(source: src);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _base64Image = null;
      _qualityScore = null;
      _qualityLabel = null;
    });

    await _classifyImage(_imageFile!);
  }

  Future<void> _classifyImage(File img) async {
    final l = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.classifyLeafWithImage(img);
      final incoming = res['base64_image'] as String;

      String? tLabel;
      int? score;
      final rawQ = res['quality'];

      if (rawQ == null || rawQ == 'Unknown') {
        tLabel = 'Unknown';
        score = null;
      } else if (rawQ is int && rawQ >= 1 && rawQ <= 4) {
        tLabel = 'T$rawQ';
        score = 5 - rawQ;
      } else if (rawQ is String) {
        final m = RegExp(r'^(T[1-4])$').firstMatch(rawQ);
        if (m != null) {
          tLabel = m.group(1);
          score = 5 - int.parse(tLabel!.substring(1));
        }
      } else {
        tLabel = 'Unknown';
        score = null;
      }

      setState(() {
        _base64Image = incoming;
        _qualityLabel = tLabel;
        _qualityScore = score;
      });
    } catch (e) {
      _showSnackBar(l.captureClassifyFailed('$e'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Proceed to prediction ─────────
  Future<void> _proceed() async {
    final l = AppLocalizations.of(context);
    if (!_isReady) {
      _showSnackBar(l.captureFirst);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoadingScreen(message: l.captureProcessing),
      ),
    );
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final pred = await ApiService.predictDegradation(
        quality: _qualityScore!,
        age: _leafAge,
        lat: pos.latitude,
        lon: pos.longitude,
      );

      Navigator.of(context).pushReplacementNamed(
        '/result',
        arguments: {
          ...pred,
          'image_base64': _base64Image,
          'leaf_age': _leafAge,
          'startingQuality': _qualityLabel,
        },
      );
      // Clear this capture so returning to the tab starts fresh & empty.
      if (mounted) {
        setState(() {
          _imageFile = null;
          _base64Image = null;
          _qualityScore = null;
          _qualityLabel = null;
          _leafAge = 1;
        });
      }
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading
      _showSnackBar(l.capturePredictFailed('$e'));
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: TeaTheme.deep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.tea.bg,
      appBar: AppBar(
        backgroundColor: context.tea.bg,
        foregroundColor: context.tea.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l.captureTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Container(
        decoration: TeaTheme.gradientOf(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _previewCard(),
              if (_qualityLabel != null && !_isLoading) ...[
                const SizedBox(height: 12),
                _resultCard(),
              ],
              const SizedBox(height: 16),
              _sourceButtons(),
              const SizedBox(height: 16),
              _tipsCard(),
              const SizedBox(height: 16),
              _leafAgeSection(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _proceedCta(),
    );
  }

  // ── Preview / capture zone ────────────────────────────────────────────────
  Widget _previewCard() {
    final l = AppLocalizations.of(context);
    Widget content;
    if (_isLoading) {
      content = SizedBox(
        height: 230,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: TeaTheme.primary),
              const SizedBox(height: 14),
              Text(l.captureAnalyzing,
                  style: const TextStyle(
                      color: TeaTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    } else if (_base64Image != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          base64Decode(_base64Image!),
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else {
      content = CustomPaint(
        painter: _DashedRRectPainter(
          color: TeaTheme.primary.withOpacity(0.35),
          radius: 18,
        ),
        child: Container(
          height: 230,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.tea.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_a_photo_rounded,
                    color: context.tea.accent, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                l.captureNoLeaf,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.tea.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.captureUseCamera,
                style: TextStyle(fontSize: 12.5, color: context.tea.sub),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: _base64Image != null
          ? TeaTheme.cardOf(context).copyWith(borderRadius: BorderRadius.circular(18))
          : null,
      padding: _base64Image != null ? const EdgeInsets.all(6) : EdgeInsets.zero,
      child: content,
    );
  }

  // ── Classification result ─────────────────────────────────────────────────
  Widget _resultCard() {
    final l = AppLocalizations.of(context);
    final label = _qualityLabel!;
    final isUnknown = label == 'Unknown';
    final c = isUnknown ? const Color(0xFFB45309) : TeaTheme.tier(label);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: isUnknown
                  ? null
                  : LinearGradient(colors: [c, c.withOpacity(0.78)]),
              color: isUnknown ? c.withOpacity(0.15) : null,
              borderRadius: BorderRadius.circular(15),
            ),
            child: isUnknown
                ? Icon(Icons.help_outline_rounded, color: c, size: 26)
                : Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUnknown ? l.captureNotValid : l.captureClassifiedGrade,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUnknown ? l.captureRetake : _tDesc(l, label),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.tea.ink,
                  ),
                ),
              ],
            ),
          ),
          if (!isUnknown)
            const Icon(Icons.check_circle_rounded,
                color: TeaTheme.bright, size: 24),
        ],
      ),
    );
  }

  // ── Camera / gallery ──────────────────────────────────────────────────────
  Widget _sourceButtons() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _sourceButton(
            icon: Icons.camera_alt_rounded,
            label: l.captureCamera,
            filled: true,
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _sourceButton(
            icon: Icons.photo_library_rounded,
            label: l.captureGallery,
            filled: false,
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: filled
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TeaTheme.primary, TeaTheme.mid],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TeaTheme.primary.withOpacity(0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: context.tea.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.tea.border),
                ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: filled ? Colors.white : context.tea.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : context.tea.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Capture tips (improves classification) ────────────────────────────────
  Widget _tipsCard() {
    final l = AppLocalizations.of(context);
    final tips = [
      (Icons.wb_sunny_rounded, l.captureTip1),
      (Icons.center_focus_strong_rounded, l.captureTip2),
      (Icons.crop_din_rounded, l.captureTip3),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: TeaTheme.cardOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: TeaTheme.gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tips_and_updates_rounded,
                    color: TeaTheme.gold, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                l.captureTipsTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: context.tea.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(t.$1, size: 16, color: context.tea.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tea.ink.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Leaf age selector ─────────────────────────────────────────────────────
  Widget _leafAgeSection() {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TeaTheme.cardOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, size: 18, color: TeaTheme.primary),
              const SizedBox(width: 8),
              Text(
                l.captureLeafAge,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.tea.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.tea.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.captureDays(_leafAge),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: TeaTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.captureLeafAgeSub,
            style: TextStyle(fontSize: 12, color: context.tea.sub),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(15, (index) {
              final day = index + 1;
              final selected = _leafAge == day;
              return GestureDetector(
                onTap: () => setState(() => _leafAge = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [TeaTheme.primary, TeaTheme.mid],
                          )
                        : null,
                    color: selected ? null : context.tea.card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected ? Colors.transparent : context.tea.border,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: TeaTheme.primary.withOpacity(0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? Colors.white : context.tea.ink,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Sticky proceed CTA ────────────────────────────────────────────────────
  Widget _proceedCta() {
    final l = AppLocalizations.of(context);
    final enabled = _isReady && !_isLoading;
    return Container(
      decoration: BoxDecoration(
        color: context.tea.bgBottom,
        border: Border(top: BorderSide(color: context.tea.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled
                    ? _proceed
                    : () => _showSnackBar(l.captureFirst),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.bright],
                    ),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: TeaTheme.primary.withOpacity(0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.captureProceed,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
}

// Dashed rounded-rect border for the empty capture zone.
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
