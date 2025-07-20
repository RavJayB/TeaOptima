// lib/screens/capture_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
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

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String? _extractT(String raw) => RegExp(r'T[1-4]').firstMatch(raw)?.group(0);

  int _tToScore(String t) => 5 - int.parse(t.substring(1));

  String _tDesc(String t) => {
        'T1': 'Highest Quality',
        'T2': 'Good Quality',
        'T3': 'Average Quality',
        'T4': 'Poor Quality',
        'Unknown': 'Not a Valid Tea Leaf',
      }[t] ?? '';

  Color _qualityColor(String? t) {
    switch (t) {
      case 'T1':
        return Colors.green.shade700;
      case 'T2':
        return Colors.lightGreen.shade600;
      case 'T3':
        return Colors.orange.shade600;
      case 'T4':
        return Colors.red.shade600;
      case 'Unknown':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

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
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.classifyLeafWithImage(img);
      final incoming = res['base64_image'] as String;

      String? tLabel;
      int? score;
      final rawQ = res['quality'];

      if (rawQ == null || rawQ == 'Unknown') {
        tLabel = 'Unknown';
        score  = null;
      }
      else if (rawQ is int && rawQ >= 1 && rawQ <= 4) {
        tLabel = 'T$rawQ';
        score  = 5 - rawQ;
      }
      else if (rawQ is String) {
        final m = RegExp(r'^(T[1-4])$').firstMatch(rawQ);
        if (m != null) {
          tLabel = m.group(1);
          score  = 5 - int.parse(tLabel!.substring(1));
        }
      }
      else{
        tLabel = 'Unknown';
        score  = null;
      }

      setState(() {
        _base64Image = incoming;
        _qualityLabel = tLabel;
        _qualityScore = score;
      });
    } catch (e) {
      _showSnackBar('Classification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Proceed to prediction ─────────
  Future<void> _proceed() async {
    if (_qualityScore == null || _base64Image == null) {
      _showSnackBar('Please classify an image first');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(message: "Processing prediction..."),
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
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading
      _showSnackBar('Prediction failed: $e');
    }
  }

  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── Image preview widget ─────────────────────────────────────────────────
 /// Shows either: loading spinner, full image, or a centered placeholder that shrinks.
Widget _preview() {
  if (_isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (_base64Image != null) {
    return Image.memory(
      base64Decode(_base64Image!),
      height: 220,
      fit: BoxFit.contain,
    );
  }

  // No fixed height here — it will size itself to the text
  return const Center(
    child: Text(
      'No image selected',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
    ),
  );
}


  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final String? chipText = (_qualityLabel != null)
        ? '$_qualityLabel — ${_tDesc(_qualityLabel!)}'
        : null;

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App-bar ──────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 100,
              backgroundColor: Colors.green.shade50,
              flexibleSpace: const FlexibleSpaceBar(
                title: Text(
                  'Capture Leaf Image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ),
            // ── Main content ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image or placeholder
                    _preview(),
                    // Modern label chip (only when image & label exist)
                    if (chipText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: Chip(
                          backgroundColor: _qualityColor(_qualityLabel),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          label: Text(
                            chipText,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Camera / gallery buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text('Camera',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo, color: Colors.white),
                          label: const Text('Gallery',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Leaf-age selector
                    const Text('Select Leaf Age (days)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(15, (index) {
                        final day = index + 1;
                        return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _leafAge == day
                            ? Colors.green.shade600
                            : const Color(0xFFFEFDF5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => setState(() => _leafAge = day),
                        child: Text(
                          '$day',
                          style: TextStyle(
                          color: _leafAge == day
                            ? Colors.white
                            : Colors.green,
                          ),
                        ),
                        );
                      }),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom button ─────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.analytics, color: Colors.white),
            label: const Text(
              'Proceed to Prediction',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: _isLoading ? null : _proceed,
          ),
        ),
      ),
    );
  }
}
