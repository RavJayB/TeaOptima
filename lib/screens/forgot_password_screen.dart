// lib/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../theme/tea_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.sendPasswordResetEmail(email: _emailC.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).resetLinkSent),
          backgroundColor: TeaTheme.deep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFFD9534F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: TeaTheme.deep,
        elevation: 0,
        title: Text(l.resetPassword,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: TeaTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: TeaTheme.primary, size: 42),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.forgotTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TeaTheme.deep,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.forgotSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      TeaTheme.input(l.emailAddressHint, Icons.email_rounded),
                  validator: (v) => v != null && v.contains('@')
                      ? null
                      : l.validEmailRequired,
                ),
              ),
              const SizedBox(height: 22),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _loading ? null : _sendReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(
                              l.sendResetLink,
                              style: const TextStyle(
                                fontSize: 15.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
