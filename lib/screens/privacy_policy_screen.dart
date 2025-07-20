import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style:TextStyle( fontWeight: FontWeight.bold, color: Color(0xFF256724))),
        backgroundColor: const Color(0xFFC6DCC5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('TeaMate Privacy Policy',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              'Your privacy is important to us. This Privacy Policy explains how TeaMate collects, uses, and protects your personal information when you use our application.\n\n'
              '1. Information Collection\n'
              '- We collect your name and email address when you register.\n\n'
              '2. Use of Information\n'
              '- Your data is used to authenticate your account and personalize your experience.\n\n'
              '3. Data Security\n'
              '- We store data securely in Firebase Firestore and do not share it with third parties.\n\n'
              '4. Changes to This Policy\n'
              '- We may update this policy from time to time. Please review it periodically.\n\n'
              'If you have any questions, contact us at ravindujayb@gmail.com.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
