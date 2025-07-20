// lib/screens/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  late User _user;
  late String _username;
  String? _avatarUrl;       // ← nullable now
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user     = _auth.currentUser!;
    _username = _user.displayName ?? 'Farmer';
    // build the DiceBear URL
    _avatarUrl = 'https://api.dicebear.com/6.x/bottts/png?seed=${_user.uid}&size=200';
  }

  Future<void> _changeUsername() async {
    final formKey = GlobalKey<FormState>();
    final ctrl    = TextEditingController(text: _username);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Username'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            maxLength: 7,
            decoration: const InputDecoration(
              labelText: 'New username',
              hintText: 'Max 7 letters',
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'Required';
              if (s == _username) return 'Pick a different name';
              if (s.length > 7)  return 'No more than 7 letters';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              setState(() => _busy = true);
              final newName = ctrl.text.trim();
              await _user.updateDisplayName(newName);
              await _user.reload();
              _user = _auth.currentUser!;
              setState(() {
                _username = newName;
                _busy = false;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username updated')),
              );
            },
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final green900 = Colors.green.shade900;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EE),
      extendBody: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Wave header ─────────────────────────────
            ClipPath(
              clipper: _BottomWaveClipper(),
              child: Container(
                height: 200,
                color: green900.withOpacity(0.1),
                child: Image.asset(
                  'assets/onboard8.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Avatar ──────────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              backgroundImage: _avatarUrl != null
                ? NetworkImage(_avatarUrl!)
                : const AssetImage('assets/login_bg.png')
                    as ImageProvider,
              onBackgroundImageError: (_, __) {
                // switch to placeholder on any network error
                if (mounted) setState(() => _avatarUrl = null);
              },
            ),

            const SizedBox(height: 12),

            // ── Username ───────────────────────────────
            Text(
              "Hi $_username..!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: green900,
              ),
            ),

            const SizedBox(height: 24),

            // ── Change name card ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: const Text('Username'),
                  subtitle: Text(_username),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: _changeUsername,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Sign out button ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: _signOut,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(size.width * 0.25, size.height,
                          size.width * 0.5, size.height - 40)
      ..quadraticBezierTo(size.width * 0.75, size.height - 80,
                          size.width, size.height - 40)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
