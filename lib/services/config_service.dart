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

  // OpenWeatherMap API Key
  static String get openWeatherApiKey {
    final key = dotenv.env['OPENWEATHER_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('Missing OPENWEATHER_API_KEY. Add it to your .env (see .env.example).');
    }
    return key;
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