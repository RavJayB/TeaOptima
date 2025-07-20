import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final String? message;
  final Future<void> Function()? futureTask;
  final void Function(BuildContext)? onTaskComplete;
  const LoadingScreen({Key? key, this.message, this.futureTask, this.onTaskComplete}) : super(key: key);

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
      });
    }
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