// lib/theme/tea_theme.dart
//
// Single source of truth for TeaOptima's visual language: the Ceylon-tea
// green palette, tier (T1–T4) colour story, and a few reusable surface
// decorations. Keeps every screen visually consistent and tea-domain native.

import 'package:flutter/material.dart';

class TeaTheme {
  // Core greens
  static const deep = Color(0xFF0F3D2E);
  static const primary = Color(0xFF1B5E3F);
  static const mid = Color(0xFF2E7D5B);
  static const bright = Color(0xFF22C55E);
  static const surface = Color(0xFFE7F4EB);
  static const border = Color(0xFFD9E8DE);
  static const gold = Color(0xFFD4A82C);

  // Background gradient
  static const bgTop = Color(0xFFF4F9F5);
  static const bgBottom = Color(0xFFEAF3EC);

  // ── Tier colour story (premium green → coarse rust) ──────────────────────
  static Color tier(String t) {
    switch (tierShort(t)) {
      case 'T1':
        return const Color(0xFF0F4D2E);
      case 'T2':
        return const Color(0xFF3E7D4E);
      case 'T3':
        return const Color(0xFFB8843A);
      case 'T4':
        return const Color(0xFFA04823);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String tierShort(String t) =>
      RegExp(r'T[1-4]').firstMatch(t)?.group(0) ?? '—';

  static String tierName(String t) {
    switch (tierShort(t)) {
      case 'T1':
        return 'Highest';
      case 'T2':
        return 'Good';
      case 'T3':
        return 'Average';
      case 'T4':
        return 'Poor';
      default:
        return 'Unknown';
    }
  }

  // ── Reusable surfaces ─────────────────────────────────────────────────────
  static BoxDecoration card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration screenGradient() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
      );

  /// Shared tea-themed input field decoration for forms.
  static InputDecoration input(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: primary, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(border),
      enabledBorder: b(border),
      focusedBorder: b(primary, 1.6),
      errorBorder: b(const Color(0xFFD9534F)),
      focusedErrorBorder: b(const Color(0xFFD9534F), 1.6),
    );
  }
}
