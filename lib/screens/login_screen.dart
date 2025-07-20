import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'package:flutter/gestures.dart';
import 'main_screen.dart';
import 'loading_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  _LoginScreenState createState() => _LoginScreenState();
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
    Navigator.of(context).pushReplacement(
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
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen(startingIndex: 0)),
            );
          },
          
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── curved image header ──────────────────────────────
          ClipPath(
            clipper: BottomWaveClipper(),
            child: Image.asset(
              'assets/Login_image.webp',
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),

          // ── form content ─────────────────────────────────────
            Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize:38,
                    fontWeight: FontWeight.bold,
                    color:Color(0xFF256724)),


                  ),
                  const SizedBox(height: 8),
                  const Text(
                  'Login to your account',
                  style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),

                  // — Email field
                    TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFC6DCC5),
                    prefixIcon:
                      const Icon(Icons.email, color: Color(0xFF256724)),
                    hintText: 'Enter your email',
                    hintStyle: const TextStyle(color: Color(0xFF256724)),
                    border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                    ),
                    ),
                    validator: (v) => v != null && v.contains('@') && v.contains('.')
                    ? null
                    : 'Enter a valid email address',
                    ),
                  const SizedBox(height: 16),

                  // — Password field
                  TextFormField(
                  controller: _passC,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscure,
                    decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFC6DCC5),
                    prefixIcon:
                      const Icon(Icons.email, color: Color(0xFF256724)),
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: Color(0xFF256724)),
                    border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF256724),
                    ),
                    onPressed: () =>
                      setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                    v != null && v.isNotEmpty ? null : 'Required',
                  ),
                  const SizedBox(height: 8),

                  // — Forgot password link
                  Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen()),
                    ),
                    child: const Text('Forgot password?',
                      style: TextStyle(color: Color(0xFF256724))),
                  ),
                  ),
                  const SizedBox(height: 24),

                  // — Login button
                  SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF256724),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                      ? const CircularProgressIndicator(
                        color: Colors.white)
                        : const Text('LOGIN',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  ),
                  const SizedBox(height: 36),

                  // — Sign up link
                    RichText(
                    text: TextSpan(
                      text: "Don't have an account?  ",
                      style: const TextStyle(color: Colors.black54),
                      children: [
                      TextSpan(
                        text: 'Sign up',
                        style: const TextStyle(
                        color: Color(0xFF256724),
                        decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                          MaterialPageRoute(
                          builder: (_) => RegisterScreen(),
                          ),
                        ),
                      ),
                      ],
                    ),
                    ),
                  const SizedBox(height: 16),
                ],
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomClipper that cuts two quadratic waves at the bottom edge.
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    // start top-left
    path.lineTo(0, 0);
    // down to 50px above bottom-left
    path.lineTo(0, size.height - 50);

    // first wave segment
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height - 50,
    );
    // second wave segment
    path.quadraticBezierTo(
      size.width * 0.75, size.height - 100,
      size.width, size.height - 50,
    );

    // up to top-right
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
