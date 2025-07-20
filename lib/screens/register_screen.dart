import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
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

    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to the Privacy Policy')),
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
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration Successful'),
          content: const Text('Welcome! Your account has been created.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 120),
              const Text(
                'Register',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF256724),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your new account',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // Name
              TextFormField(
                controller: _nameC,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFC6DCC5),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF256724)),
                  hintText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) =>
                    v != null && v.isNotEmpty ? null : 'Name is required',
              ),
              const SizedBox(height: 20),

              // Email
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFC6DCC5),
                  prefixIcon: const Icon(Icons.email, color: Color(0xFF256724)),
                  hintText: 'abc123@gmail.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v != null && v.contains('@')
                    ? null
                    : 'Valid email is required',
              ),
              const SizedBox(height: 20),

              // Password
              TextFormField(
                controller: _passC,
                obscureText: _obscure,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFC6DCC5),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF256724)),
                  hintText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v != null && v.length >= 6
                    ? null
                    : 'Password must be at least 6 characters',
              ),
              const SizedBox(height: 16),

              // Privacy Policy checkbox + link
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    activeColor: const Color(0xFF256724),
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                    Expanded(
                    child: RichText(
                      text: TextSpan(
                      text: 'I agree to the ',
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: Color(0xFF256724),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                            builder: (_) => PrivacyPolicyScreen(),
                            ),
                          );
                          },
                        ),
                      ],
                      ),
                    ),
                    ),
                  ],
                  ),
              const SizedBox(height: 34),

              // Register button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF256724),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('REGISTER',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              // Already have account?
              RichText(
                text: TextSpan(
                  text: "Already have an account?  ",
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Sign in',
                      style: const TextStyle(
                        color: Color(0xFF256724),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => LoginScreen()),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
