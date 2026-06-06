// lib/services/locale_controller.dart
//
// Global, persisted app-language controller. Drives MaterialApp.locale via a
// ValueNotifier so a language change rebuilds the whole app instantly.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  static const _key = 'app_locale';

  /// Supported languages: code → native display name.
  static const supported = <String, String>{
    'en': 'English',
    'si': 'සිංහල',
    'ta': 'தமிழ்',
  };

  /// The active locale. Defaults to English until [load] runs.
  static final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && supported.containsKey(code)) {
      locale.value = Locale(code);
    }
  }

  static Future<void> setLocale(String code) async {
    if (!supported.containsKey(code)) return;
    locale.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  static String get currentCode => locale.value.languageCode;
  static String get currentName => supported[currentCode] ?? 'English';
}
