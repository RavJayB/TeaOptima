import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../theme/tea_theme.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false, _obscure = true, _agreed = false;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context);
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.agreePrivacyError),
          backgroundColor: TeaTheme.deep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.signUp(
        name: _nameC.text.trim(),
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: TeaTheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: TeaTheme.primary, size: 30),
          ),
          title: Text(l.registrationSuccessTitle,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            l.registrationSuccessBody,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeaTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.commonContinue,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
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
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: Column(
          children: [
            _header(l),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameC,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            TeaTheme.input(l.fullNameHint, Icons.person_rounded),
                        validator: (v) => v != null && v.trim().isNotEmpty
                            ? null
                            : l.nameRequired,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: TeaTheme.input(
                            l.emailAddressHint, Icons.email_rounded),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : l.validEmailRequired,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passC,
                        obscureText: _obscure,
                        decoration: TeaTheme.input(
                          l.passwordMinHint,
                          Icons.lock_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: TeaTheme.primary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v != null && v.length >= 6
                            ? null
                            : l.passwordMin6,
                      ),
                      const SizedBox(height: 8),
                      _privacyRow(l),
                      const SizedBox(height: 20),
                      _registerButton(l),
                      const SizedBox(height: 22),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: '${l.alreadyHaveAccount}  ',
                          style: TextStyle(color: Colors.grey.shade600),
                          children: [
                            TextSpan(
                              text: l.signIn,
                              style: const TextStyle(
                                color: TeaTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const LoginScreen()),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Icon(Icons.eco_rounded,
                size: 140, color: Colors.white.withOpacity(0.08)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'TEAOPTIMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.createAccount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.registerSubtitle,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyRow(AppLocalizations l) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: _agreed,
            activeColor: TeaTheme.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (v) => setState(() => _agreed = v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: l.iAgreeTo,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              children: [
                TextSpan(
                  text: l.privacyPolicy,
                  style: const TextStyle(
                    color: TeaTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _registerButton(AppLocalizations l) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _loading ? null : _submit,
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
                    l.createAccount,
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
    );
  }
}
