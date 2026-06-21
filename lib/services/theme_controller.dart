// lib/services/theme_controller.dart
//
// App-wide appearance (light / dark / follow-system), persisted across
// launches. Mirrors LocaleController's pattern: a static ValueNotifier the
// MaterialApp listens to, so switching is instant everywhere.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static const _key = 'app_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'light':
        mode.value = ThemeMode.light;
      case 'dark':
        mode.value = ThemeMode.dark;
      default:
        mode.value = ThemeMode.system;
    }
  }

  static Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
