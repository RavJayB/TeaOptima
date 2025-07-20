// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// Stream of auth state changes (signed in / out)
  static Stream<User?> get userChanges => _auth.userChanges();

  /// Register a new user with [name], [email], [password]
  static Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // save displayName
    await cred.user!.updateDisplayName(name);
    return cred;
  }

  /// Alias for signUp
  static Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) =>
      signUp(name: name, email: email, password: password);

  /// Sign in existing user with [email] & [password]
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Sign out
  static Future<void> signOut() => _auth.signOut();

  /// Send a password reset email to [email]
  static Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);
}
