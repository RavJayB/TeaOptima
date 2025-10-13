import 'package:flutter/material.dart';

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
          title: const Text('Login Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                // Go back to the previous screen (login screen)
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Icon(
                    Icons.emoji_nature,
                    size: 64,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 24),
              Text(
                widget.message!,
                style: const TextStyle(fontSize: 20, color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
      ),
    );
  }
} 