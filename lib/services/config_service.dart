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
    return dotenv.env['OPENWEATHER_API_KEY'] ?? 
           '3683f0b1c4b8dede66df6c597ae5b5b2'; // Fallback for existing users
  }

  // Backend service URLs
  static String get imageServiceUrl {
    return dotenv.env['IMAGE_SERVICE_URL'] ?? 
           'https://image-svc-1036518290491.asia-south1.run.app/classify';
  }

  static String get degradeServiceUrl {
    return dotenv.env['DEGRADE_SERVICE_URL'] ?? 
           'https://degrade-svc-1036518290491.asia-south1.run.app/predict';
  }

  // Firebase configuration (optional - firebase_options.dart is primary)
  static String get firebaseProjectId {
    return dotenv.env['FIREBASE_PROJECT_ID'] ?? 'teamate-2b851';
  }

  static String get firebaseStorageBucket {
    return dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? 'teamate-2b851.firebasestorage.app';
  }
} 