import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(Supabase.instance.client.auth),
);

class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
  User? get currentUser => _auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
    String? city,
  }) async {
    return await _auth.signUp(
      email: email,
      password: password,
      data: {'name': ?name, 'city': ?city},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signInWithGoogle({String? redirectTo}) async {
    return await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo ?? 'io.supabase.neutrawise://login-callback',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo ?? 'io.supabase.neutrawise://reset-password',
    );
  }

  /// Permanently deletes the account and all of its data.
  ///
  /// Email/password users must re-enter their password (it is verified before
  /// anything is deleted). Social-login users have no password to verify.
  Future<void> deleteAccount({String? password}) async {
    final user = currentUser;
    if (user == null) return;

    final isEmailAccount =
        (user.appMetadata['provider'] as String? ?? 'email') == 'email';
    if (isEmailAccount) {
      if (password == null || password.isEmpty || user.email == null) {
        throw AuthException('Enter your password to delete your account.');
      }
      await _auth.signInWithPassword(email: user.email!, password: password);
    }

    final client = Supabase.instance.client;
    try {
      await client.storage.from('avatars').remove(['${user.id}/avatar.jpg']);
    } catch (_) {
      // No stored avatar (or already removed) - nothing to clean up.
    }

    // Removes the sign-in account; every app table cascades from it.
    await client.rpc('delete_my_account');

    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The user no longer exists on the server; clearing the local session is
      // all that matters and the auth listener handles the rest.
    }
  }
}
