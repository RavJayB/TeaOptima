// lib/screens/verify_email_screen.dart
//
// Gate shown when a signed-in email/password user hasn't confirmed their
// address yet. Polls Firebase for verification, and offers resend / switch
// account. Google sign-ins never land here (they're pre-verified).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../theme/tea_theme.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  bool _checking = false;
  bool _canResend = true;
  int _resendIn = 0;
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    // Poll the server periodically so the user advances automatically once
    // they tap the link in their inbox.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldown?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);
    final verified = await AuthService.refreshEmailVerified();
    if (!mounted) return;
    if (verified) {
      _poll?.cancel();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen(startingIndex: 0)),
        (route) => false,
      );
      return;
    }
    if (!silent) {
      setState(() => _checking = false);
      final l = AppLocalizations.of(context);
      _snack(l.verifyNotYet);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    final l = AppLocalizations.of(context);
    try {
      await AuthService.sendVerificationEmail();
      if (!mounted) return;
      _snack(l.verifyResent);
      // brief cooldown to avoid spamming Firebase
      setState(() {
        _canResend = false;
        _resendIn = 30;
      });
      _cooldown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _resendIn--);
        if (_resendIn <= 0) {
          t.cancel();
          setState(() => _canResend = true);
        }
      });
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _useAnother() async {
    _poll?.cancel();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: TeaTheme.deep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final email = AuthService.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── icon badge ──
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TeaTheme.primary.withOpacity(0.32),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.verifyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: TeaTheme.deep,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.verifyBody(email),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // ── primary: I've verified ──
                  _primaryButton(l),
                  const SizedBox(height: 12),
                  // ── resend ──
                  OutlinedButton.icon(
                    onPressed: _canResend ? _resend : null,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _canResend
                          ? l.verifyResend
                          : '${l.verifyResend} ($_resendIn)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TeaTheme.primary,
                      side: const BorderSide(color: TeaTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _useAnother,
                    child: Text(
                      l.verifyUseAnother,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(AppLocalizations l) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _checking ? null : () => _check(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
            ),
            boxShadow: [
              BoxShadow(
                color: TeaTheme.primary.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: _checking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(
                    l.verifyImVerified,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
