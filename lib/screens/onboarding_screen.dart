import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/tea_theme.dart';

class OnboardingScreen extends StatefulWidget {
  /// Optional callback if the parent widget wants to know
  /// that onboarding is finished.
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  Timer? _timer;
  int _current = 0;

  final List<String> _images = [
    'assets/onboard1.jpg',
    'assets/onboard4.webp',
    'assets/onboard7.jpg',
    'assets/onboard11.jpg',
    'assets/onboard12.jpg',
    'assets/onboard13.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final next = (_ctrl.page?.round() ?? 0) + 1;
      _ctrl.animateToPage(
        next % _images.length,
        duration: const Duration(milliseconds: 700),
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

  Future<void> _completeAndNavigate(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    widget.onComplete?.call();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    await _completeAndNavigate(user != null ? '/main' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final copyList = <(String, String)>[
      (l.onbTitle1, l.onbSub1),
      (l.onbTitle2, l.onbSub2),
      (l.onbTitle3, l.onbSub3),
      (l.onbTitle4, l.onbSub4),
      (l.onbTitle5, l.onbSub5),
      (l.onbTitle6, l.onbSub6),
    ];
    final copy = copyList[_current % copyList.length];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background slideshow ──
          PageView.builder(
            controller: _ctrl,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Image.asset(_images[i], fit: BoxFit.cover),
          ),

          // ── Tea-tinted gradient overlay ──
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  TeaTheme.deep.withOpacity(0.55),
                  TeaTheme.deep.withOpacity(0.92),
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // brand pill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('TEAOPTIMA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 1.8,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_images.length, (i) {
                      final active = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // rotating headline + subtitle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Column(
                      key: ValueKey(_current),
                      children: [
                        Text(
                          copy.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 10)
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          copy.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // primary: Get Started
                  _primaryButton(),
                  const SizedBox(height: 12),
                  // secondary: Sign in / Create account
                  Row(
                    children: [
                      Expanded(
                        child: _glassButton(
                          l.signIn,
                          () => _completeAndNavigate('/login'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _glassButton(
                          l.createAccount,
                          () => _completeAndNavigate('/register'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _finish,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context).getStarted,
                style: const TextStyle(
                  color: TeaTheme.deep,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: TeaTheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.40)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
