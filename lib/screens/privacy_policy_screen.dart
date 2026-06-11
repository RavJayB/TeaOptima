import 'package:flutter/material.dart';

import '../theme/tea_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(IconData, String, String)>[
    (
      Icons.badge_rounded,
      'Information We Collect',
      'We collect your name and email address when you register, and the tea-leaf predictions you create (image, location, weather, and quality forecast).',
    ),
    (
      Icons.tune_rounded,
      'How We Use It',
      'Your data authenticates your account, personalizes your experience, and powers your prediction history and estate insights.',
    ),
    (
      Icons.lock_rounded,
      'Data Security',
      'Your data is stored securely in Google Firebase (Firestore). We do not sell or share it with third parties.',
    ),
    (
      Icons.location_on_rounded,
      'Location & Weather',
      'Location is used only to fetch local weather for accurate degradation forecasts. It is never shared externally.',
    ),
    (
      Icons.update_rounded,
      'Policy Updates',
      'We may update this policy from time to time. Please review it periodically for changes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tea.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.tea.ink,
        elevation: 0,
        title: const Text('Privacy Policy',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Container(
        decoration: TeaTheme.gradientOf(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.privacy_tip_rounded,
                        color: Colors.white, size: 26),
                    SizedBox(height: 10),
                    Text(
                      'Your privacy matters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'How TeaOptima collects, uses, and protects your information.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: TeaTheme.cardOf(context),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.tea.surface,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(s.$1, color: context.tea.accent, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.$2,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.tea.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.$3,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.tea.sub,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.tea.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.tea.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        color: context.tea.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Questions? Contact us at ravindujayb@gmail.com',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.tea.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
