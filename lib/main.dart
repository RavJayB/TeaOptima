// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';
import 'services/locale_controller.dart';
import 'services/remote_config_service.dart';
import 'services/theme_controller.dart';
import 'theme/tea_theme.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/result_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration service
  await ConfigService.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Fetch latest indicative tea prices (graceful: never blocks fatally).
  await RemoteConfigService.init();

  // Load the user's saved app language (English / Sinhala / Tamil)
  await LocaleController.load();

  // Load the user's saved appearance (light / dark / system)
  await ThemeController.load();

  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool("onboardingCompleted") ?? false;

  runApp(TeaQualityApp(showOnboarding: !onboardingCompleted));
}

class TeaQualityApp extends StatelessWidget {
  final bool showOnboarding;
  const TeaQualityApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language or appearance changes.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) =>
          ValueListenableBuilder<Locale>(
        valueListenable: LocaleController.locale,
        builder: (context, locale, _) {
          return MaterialApp(
          title: 'TeaOptima',
          debugShowCheckedModeBanner: false,
          theme: TeaTheme.lightTheme(),
          darkTheme: TeaTheme.darkTheme(),
          themeMode: themeMode,

          // ── Localization ──
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,

          // ① If onboarding not done, show it first
          home: showOnboarding
              ? OnboardingScreen(
                  onComplete: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboardingCompleted', true);

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) =>
                            const TeaQualityApp(showOnboarding: false),
                      ),
                      (route) => false,
                    );
                  },
                )

              // ② Else show login or main based on auth state
              : StreamBuilder<User?>(
                  stream: AuthService.userChanges,
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingScreen(message: "Loading...");
                    }
                    if (!snapshot.hasData) {
                      return const LoginScreen();
                    }
                    // Email/password users must confirm their address first.
                    // Google sign-ins report emailVerified == true.
                    if (!snapshot.data!.emailVerified) {
                      return const VerifyEmailScreen();
                    }
                    return const MainScreen();
                  },
                ),

          // Named routes for everything else
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/forgot': (_) => const ForgotPasswordScreen(),
            '/main': (_) => const MainScreen(),
            '/home': (_) => const HomeScreen(),
            '/capture': (_) => CaptureScreen(),
            '/result': (_) => ResultScreen(),
            '/history': (_) => const HistoryScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
          );
        },
      ),
    );
  }
}
