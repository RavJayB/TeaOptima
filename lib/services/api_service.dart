// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class ApiService {
  static String get imageSvcUrl => ConfigService.imageServiceUrl;
  static String get degradeSvcUrl => ConfigService.degradeServiceUrl;

  /// 🔑 Fetches a fresh Firebase ID token and returns the standard headers
  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    final idToken = await user.getIdToken();
    return {
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  /// 📸 Call image-svc: upload image and get back quality + base64 image
  static Future<Map<String, dynamic>> classifyLeafWithImage(File imageFile) async {
    final uri = Uri.parse(imageSvcUrl);
    final req = http.MultipartRequest('POST', uri);

    // attach our auth header
    req.headers.addAll(await _authHeaders(json: false));

    req.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Image classification failed (${streamed.statusCode}): $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    // pull out the numeric tier from e.g. "T1 (…)"
    final match   = RegExp(r'\d+').firstMatch(data['quality'].toString());
    final quality = int.tryParse(match?.group(0) ?? '') ?? 0;

    return {
      'quality': quality,
      'base64_image': data['image_base64'],
    };
  }

  /// 🔮 Call degrade-svc: get 15-day prediction + SHAP explanation
  static Future<Map<String, dynamic>> predictDegradation({
    required int quality,
    required double lat,
    required double lon,
    int age = 1,
  }) async {
    final uri = Uri.parse(degradeSvcUrl);
    final headers = await _authHeaders();
    final body = jsonEncode({
      'current_quality': quality,
      'current_age': age,
      'lat': lat,
      'lon': lon,
    });

    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 200) {
      throw Exception('Prediction failed (${resp.statusCode}): ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
