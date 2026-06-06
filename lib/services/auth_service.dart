// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of auth state changes (signed in / out)
  static Stream<User?> get userChanges => _auth.userChanges();

  /// Currently signed-in user (or null).
  static User? get currentUser => _auth.currentUser;

  /// Register a new user with [name], [email], [password].
  /// Sets the display name and immediately sends a verification email.
  static Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(name);
    // Email/password accounts start unverified — send the confirmation link.
    await cred.user!.sendEmailVerification();
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

  /// Sign in (or sign up) with Google. Returns the credential, or `null` if
  /// the user cancelled the Google chooser. Google accounts are pre-verified.
  static Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user dismissed the picker

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign out of both Firebase and Google.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // not signed in with Google — ignore
    }
    await _auth.signOut();
  }

  /// Send a password reset email to [email]
  static Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Map a Firebase auth exception to a safe, localized message. Never surface
  /// raw exceptions to the UI (avoids info leaks / user enumeration).
  static String friendlyAuthError(AppLocalizations l, Object e) {
    final s = e.toString();
    if (s.contains('email-already-in-use')) return l.authErrEmailInUse;
    if (s.contains('invalid-email')) return l.invalidEmail;
    if (s.contains('weak-password')) return l.passwordMin6;
    if (s.contains('network-request-failed')) return l.authErrNetwork;
    return l.authErrGeneric;
  }

  // ── Email verification helpers ────────────────────────────────────────────

  /// Whether the signed-in user's email is verified.
  /// Google (and other federated) sign-ins are inherently verified.
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// (Re)send the verification email to the current user.
  static Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Refresh the user from the server and report whether the email is now
  /// verified — used by the verify-email screen to poll for confirmation.
  static Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
