import 'package:flutter/material.dart';

import '../theme/tea_theme.dart';

class LoadingScreen extends StatefulWidget {
  final String? message;
  final Future<void> Function()? futureTask;
  final void Function(BuildContext)? onTaskComplete;
  final void Function(BuildContext, String)? onTaskError;
  const LoadingScreen({
    Key? key, 
    this.message, 
    this.futureTask, 
    this.onTaskComplete,
    this.onTaskError,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.futureTask != null) {
      widget.futureTask!().then((_) {
        if (widget.onTaskComplete != null && mounted) {
          widget.onTaskComplete!(context);
        }
      }).catchError((error) {
        if (mounted) {
          String errorMessage = 'An error occurred';
          
          // Handle Firebase Auth errors following security best practices
          if (error.toString().contains('invalid-credential')) {
            errorMessage = 'Invalid email or password. Please check your credentials and try again.';
          } else if (error.toString().contains('user-disabled')) {
            errorMessage = 'This account has been disabled. Please contact support.';
          } else if (error.toString().contains('too-many-requests')) {
            errorMessage = 'Too many failed attempts. Please try again later.';
          } else if (error.toString().contains('network-request-failed')) {
            errorMessage = 'Network error. Please check your internet connection.';
          } else if (error.toString().contains('operation-not-allowed')) {
            errorMessage = 'Email/password sign-in is not enabled. Please contact support.';
          } else {
            errorMessage = 'Login failed. Please try again.';
          }
          
          if (widget.onTaskError != null) {
            widget.onTaskError!(context, errorMessage);
          } else {
            // Default error handling - show dialog and go back
            _showErrorDialog(context, errorMessage);
          }
        }
      });
    }
  }
  

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFD9534F).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFD9534F), size: 28),
          ),
          title: const Text(
            'Login Failed',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  Navigator.of(context).pop(); // Back to login
                },
                child: const Text('Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tea.bg,
      body: Container(
        decoration: TeaTheme.gradientOf(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF1B5E3F)),
                      backgroundColor: const Color(0xFF1B5E3F).withOpacity(0.10),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B5E3F), Color(0xFF2E7D5B)],
                      ),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        size: 38, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                widget.message ?? 'Working…',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.tea.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'TeaOptima is analyzing your leaf',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.tea.sub,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}