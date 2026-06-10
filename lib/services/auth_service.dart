import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Auth. Supports email/password and anonymous sign-in.
/// Anonymous users can upgrade to a full account later without losing data.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  String? get uid => currentUser?.uid;
  String? get email => currentUser?.email;
  String? get displayName => currentUser?.displayName;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in anonymously — creates a temporary account so data can be
  /// stored in Firestore immediately without requiring an email.
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
    notifyListeners();
  }

  /// Create a full account with email and password.
  /// If currently signed in anonymously, links the account so data is preserved.
  Future<void> registerWithEmail(String email, String password,
      {String? displayName}) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    if (isAnonymous && currentUser != null) {
      // Upgrade anonymous → full account, keeps the same UID so data stays
      await currentUser!.linkWithCredential(credential);
    } else {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    if (displayName != null && displayName.isNotEmpty) {
      await currentUser?.updateDisplayName(displayName);
    }
    notifyListeners();
  }

  /// Sign in with email and password.
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    notifyListeners();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
