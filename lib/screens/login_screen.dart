import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../theme/tea_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';
import 'verify_email_screen.dart';
import 'loading_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false, _obscure = true;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoadingScreen(
          message: "Logging in...",
          futureTask: () async {
            await AuthService.signIn(
              email: _emailC.text.trim(),
              password: _passC.text.trim(),
            );
          },
          onTaskComplete: (ctx) {
            final verified = AuthService.isEmailVerified;
            Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => verified
                    ? const MainScreen(startingIndex: 0)
                    : const VerifyEmailScreen(),
              ),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _google() async {
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) {
        if (mounted) setState(() => _loading = false);
        return; // user cancelled the Google chooser
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen(startingIndex: 0)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.authGoogleFailed('$e')),
            backgroundColor: const Color(0xFFD9534F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            // ── wave-clipped hero with tea scrim + brand ──────────
            _heroHeader(),
            // ── form ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.welcomeBack,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: TeaTheme.deep,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.loginSubtitle,
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec(l.emailHint, Icons.email_rounded),
                        validator: (v) =>
                            v != null && v.contains('@') && v.contains('.')
                                ? null
                                : l.invalidEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passC,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: _obscure,
                        decoration: _dec(
                          l.passwordHint,
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
                        validator: (v) =>
                            v != null && v.isNotEmpty ? null : l.required,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ForgotPasswordScreen()),
                          ),
                          child: Text(l.forgotPassword,
                              style: const TextStyle(
                                  color: TeaTheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _primaryButton(l),
                      const SizedBox(height: 18),
                      _orDivider(l),
                      const SizedBox(height: 18),
                      _googleButton(l),
                      const SizedBox(height: 24),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: '${l.noAccount}  ',
                          style: TextStyle(color: Colors.grey.shade600),
                          children: [
                            TextSpan(
                              text: l.signUp,
                              style: const TextStyle(
                                color: TeaTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => RegisterScreen()),
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

  Widget _heroHeader() {
    return ClipPath(
      clipper: BottomWaveClipper(),
      child: SizedBox(
        height: 290,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/Login_image.webp', fit: BoxFit.cover),
            // tea-green scrim for depth + legibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TeaTheme.deep.withOpacity(0.55),
                    TeaTheme.primary.withOpacity(0.20),
                    TeaTheme.deep.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.eco_rounded, color: Colors.white, size: 17),
                        SizedBox(width: 6),
                        Text(
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(AppLocalizations l) {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l.login,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orDivider(AppLocalizations l) {
    return Row(
      children: [
        const Expanded(child: Divider(color: TeaTheme.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            l.authOr,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: TeaTheme.border, thickness: 1)),
      ],
    );
  }

  Widget _googleButton(AppLocalizations l) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _loading ? null : _google,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: TeaTheme.border),
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: TeaTheme.primary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _googleGlyph(),
                      const SizedBox(width: 10),
                      Text(
                        l.authContinueGoogle,
                        style: const TextStyle(
                          fontSize: 15,
                          color: TeaTheme.deep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Placeholder "G" mark — swap for the official multicolor Google asset
  // before Play Store release (branding-guideline compliance).
  Widget _googleGlyph() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: TeaTheme.primary, size: 20),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(TeaTheme.border),
      enabledBorder: border(TeaTheme.border),
      focusedBorder: border(TeaTheme.primary, 1.6),
      errorBorder: border(const Color(0xFFD9534F)),
      focusedErrorBorder: border(const Color(0xFFD9534F), 1.6),
    );
  }
}

/// CustomClipper that cuts two quadratic waves at the bottom edge.
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height - 50,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height - 100,
      size.width, size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
