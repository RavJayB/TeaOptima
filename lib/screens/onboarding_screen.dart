import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends StatefulWidget {
  /// Optional callback if the parent widget wants to know
  /// that onboarding is finished.
  final VoidCallback? onComplete;
  const OnboardingScreen({Key? key, this.onComplete}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  Timer? _timer;

  final List<String> _images = [
    'assets/onboard1.jpg',
    'assets/onboard4.webp',
    'assets/onboard7.jpg',
    'assets/onboard11.jpg',
    'assets/onboard12.jpg',
    'assets/onboard13.jpg',
  ];

  // ────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      final next = (_ctrl.page?.round() ?? 0) + 1;
      _ctrl.animateToPage(
        next % _images.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────
  /// Marks onboarding as finished, then replaces the nav-stack with [route].
  Future<void> _completeAndNavigate(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    widget.onComplete?.call();         // notify parent if needed

    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (_) => false,                    // clear the back-stack
    );
  }

  /// Called by “Get Started” — chooses Main or Login automatically.
  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    await _completeAndNavigate(user != null ? '/main' : '/login');
  }

  // ────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ----- Background slideshow -----
          PageView.builder(
            controller: _ctrl,
            itemCount: _images.length,
            itemBuilder: (_, i) => DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_images[i]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // ----- Dark gradient overlay -----
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black54],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ----- Bottom controls -----
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Let AI do the Prediction',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Sign In ───────────────────────────────────────
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white70,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _completeAndNavigate('/login'),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),

                  // ── Register ─────────────────────────────────────
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white38,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _completeAndNavigate('/register'),
                    child: const Text('Create an account'),
                  ),
                  const SizedBox(height: 24),

                  // ── Get Started (auto route) ─────────────────────
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Get Started',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
