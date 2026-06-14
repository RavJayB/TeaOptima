// lib/services/config_service.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // .env file doesn't exist or can't be loaded
      // This is okay for development if using fallback values
      print('Warning: Could not load .env file: $e');
    }
  }

  // Backend service URLs
  // Note: These are public service endpoints, not secrets. Protection is via authentication on the backend.
  // For production, override these in .env to use your own services or different environments.
  static String get imageServiceUrl {
    return dotenv.env['IMAGE_SERVICE_URL'] ??
           'https://image-svc-1036518290491.asia-south1.run.app/classify';
  }

  static String get degradeServiceUrl {
    return dotenv.env['DEGRADE_SERVICE_URL'] ??
           'https://degrade-svc-1036518290491.asia-south1.run.app/predict';
  }

  // Weather endpoints — derived from degradeServiceUrl by stripping the /predict suffix.
  // Weather + reverse geocode go through the backend so the OpenWeather key stays server-side.
  static String get _degradeBase =>
      degradeServiceUrl.replaceAll(RegExp(r'/predict/?$'), '');

  static String get weatherCurrentUrl => '$_degradeBase/weather/current';
  static String get weatherLocationUrl => '$_degradeBase/weather/location';

  // Firebase configuration (optional - firebase_options.dart is primary)
  // Note: Project ID and storage bucket are public identifiers, not secrets. Security is via Firebase Rules.
  // These can be overridden in .env for different environments (dev/staging/prod).
  static String get firebaseProjectId {
    return dotenv.env['FIREBASE_PROJECT_ID'] ?? 'teamate-2b851';
  }

  static String get firebaseStorageBucket {
    return dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? 'teamate-2b851.firebasestorage.app';
  }
} 