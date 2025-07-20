// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_screen.dart';
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

  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool("onboardingCompleted") ?? false;

  runApp(TeaQualityApp(showOnboarding: !onboardingCompleted));
}

class TeaQualityApp extends StatelessWidget {
  final bool showOnboarding;
  const TeaQualityApp({Key? key, required this.showOnboarding})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tea Leaf Quality App',
      theme: ThemeData(primarySwatch: Colors.green),

      // ① If onboarding not done, show it first
      home: showOnboarding
          ? OnboardingScreen(
              onComplete: () async {
                // Mark onboarding done
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true);

                // Replace with a fresh TeaQualityApp without onboarding
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const TeaQualityApp(showOnboarding: false),
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
                return const MainScreen();
              },
            ),

      // Named routes for everything else
      routes: {
        '/login': (_) =>  LoginScreen(),
        '/register': (_) =>  RegisterScreen(),
        '/forgot': (_) =>  ForgotPasswordScreen(),
        '/main': (_) =>  MainScreen(),
        '/home': (_) =>  HomeScreen(),
        '/capture': (_) =>  CaptureScreen(),
        '/result': (_) =>  ResultScreen(),
        '/history': (_) =>  HistoryScreen(),
        '/profile': (_) =>  ProfileScreen(),

      },
    );
  }
}