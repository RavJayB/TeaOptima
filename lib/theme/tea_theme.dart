// lib/theme/tea_theme.dart
//
// Single source of truth for TeaOptima's visual language: the Ceylon-tea
// green palette, tier (T1–T4) colour story, and reusable surface decorations.
//
// Supports light AND dark mode via [TeaPalette]: screens read theme-aware
// colours with `context.tea.<field>` (e.g. `context.tea.card`), while the
// brand greens / tier colours stay constant (they sit on coloured surfaces
// that work in both modes).

import 'package:flutter/material.dart';

/// Theme-aware surface & text colours. Resolved per-brightness via
/// `TeaTheme.of(context)` / `context.tea`.
class TeaPalette {
  final Color bg; // scaffold / sheet background (top of gradient)
  final Color bgBottom; // bottom of background gradient
  final Color card; // elevated card fill
  final Color surface; // tinted chip / icon-badge fill
  final Color border; // hairline borders
  final Color ink; // primary text
  final Color sub; // secondary text
  final Color faint; // tertiary text / hints
  final Color inputFill; // form field fill
  final Color accent; // links / interactive green (brighter in dark)
  final bool isDark;

  const TeaPalette({
    required this.bg,
    required this.bgBottom,
    required this.card,
    required this.surface,
    required this.border,
    required this.ink,
    required this.sub,
    required this.faint,
    required this.inputFill,
    required this.accent,
    required this.isDark,
  });
}

class TeaTheme {
  // ── Brand greens (constant across modes — used on coloured surfaces) ─────
  static const deep = Color(0xFF0F3D2E);
  static const primary = Color(0xFF1B5E3F);
  static const mid = Color(0xFF2E7D5B);
  static const bright = Color(0xFF22C55E);
  static const gold = Color(0xFFD4A82C);

  // Legacy light-mode aliases (kept so older code keeps compiling; prefer
  // `context.tea.*` in screens).
  static const surface = Color(0xFFE7F4EB);
  static const border = Color(0xFFD9E8DE);
  static const bgTop = Color(0xFFF4F9F5);
  static const bgBottom = Color(0xFFEAF3EC);

  // ── Palettes ──────────────────────────────────────────────────────────────
  static const lightPalette = TeaPalette(
    bg: Color(0xFFF4F9F5),
    bgBottom: Color(0xFFEAF3EC),
    card: Colors.white,
    surface: Color(0xFFE7F4EB),
    border: Color(0xFFD9E8DE),
    ink: Color(0xFF0F3D2E),
    sub: Color(0xFF5C6E64),
    faint: Color(0xFF93A29A),
    inputFill: Colors.white,
    accent: primary,
    isDark: false,
  );

  // "Midnight tea garden" — deep green-tinted charcoals, soft mint text.
  static const darkPalette = TeaPalette(
    bg: Color(0xFF0C1512),
    bgBottom: Color(0xFF090F0B),
    card: Color(0xFF15211B),
    surface: Color(0xFF1D2D24),
    border: Color(0xFF28392F),
    ink: Color(0xFFE9F3EC),
    sub: Color(0xFFA8BDB0),
    faint: Color(0xFF708579),
    inputFill: Color(0xFF18251E),
    accent: Color(0xFF3CB97E),
    isDark: true,
  );

  static TeaPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkPalette
          : lightPalette;

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

  // ── Reusable surfaces (theme-aware) ───────────────────────────────────────
  static BoxDecoration cardOf(BuildContext context) {
    final p = of(context);
    return BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: p.border),
      boxShadow: [
        BoxShadow(
          color: p.isDark
              ? Colors.black.withOpacity(0.35)
              : primary.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration gradientOf(BuildContext context) {
    final p = of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.bg, p.bgBottom],
      ),
    );
  }

  // Legacy light-only helpers (prefer cardOf / gradientOf).
  @Deprecated('Light-only; breaks dark mode. Use TeaTheme.cardOf(context).')
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

  @Deprecated('Light-only; breaks dark mode. Use TeaTheme.gradientOf(context).')
  static BoxDecoration screenGradient() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
      );

  /// Shared tea-themed input field decoration for forms (theme-aware).
  static InputDecoration input(String hint, IconData icon,
      {Widget? suffix, BuildContext? context}) {
    final p = context != null ? of(context) : lightPalette;
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      filled: true,
      fillColor: p.inputFill,
      hintText: hint,
      hintStyle: TextStyle(color: p.faint),
      prefixIcon: Icon(icon, color: p.accent, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(p.border),
      enabledBorder: b(p.border),
      focusedBorder: b(p.accent, 1.6),
      errorBorder: b(const Color(0xFFD9534F)),
      focusedErrorBorder: b(const Color(0xFFD9534F), 1.6),
    );
  }

  // ── Material ThemeData for both modes ─────────────────────────────────────
  static ThemeData lightTheme() => _theme(lightPalette, Brightness.light);
  static ThemeData darkTheme() => _theme(darkPalette, Brightness.dark);

  static ThemeData _theme(TeaPalette p, Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: b,
    ).copyWith(
      primary: p.accent,
      surface: p.card,
      onSurface: p.ink,
      outline: p.border,
    );
    return ThemeData(
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: p.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: p.sub, fontSize: 14, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withOpacity(0.30),
        selectionHandleColor: p.accent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Sugar: `context.tea.card`, `context.tea.ink`, …
extension TeaBuildContextX on BuildContext {
  TeaPalette get tea => TeaTheme.of(this);
}
