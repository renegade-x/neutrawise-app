import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/data/repositories/auth_repository.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/sync/sync_manager.dart';

import 'package:neutrawise/services/push_notification_service.dart';

class AuthStateData {
  final bool isAuthenticated;
  final User? user;
  final bool loading;
  final String? error;
  final bool hasProfileSetup;
  final bool hasSeenOnboarding;

  AuthStateData({
    required this.isAuthenticated,
    required this.user,
    required this.loading,
    required this.error,
    required this.hasProfileSetup,
    required this.hasSeenOnboarding,
  });

  factory AuthStateData.initial() => AuthStateData(
    isAuthenticated: false,
    user: null,
    loading: true,
    error: null,
    hasProfileSetup: false,
    hasSeenOnboarding: false,
  );

  AuthStateData copyWith({
    bool? isAuthenticated,
    User? user,
    bool? loading,
    String? error,
    bool? hasProfileSetup,
    bool? hasSeenOnboarding,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
      hasProfileSetup: hasProfileSetup ?? this.hasProfileSetup,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }
}

class AuthNotifier extends Notifier<AuthStateData> {
  late final AuthRepository _authRepo;

  @override
  AuthStateData build() {
    _authRepo = ref.watch(authRepositoryProvider);
    Future.microtask(() => _initializeSession());
    return AuthStateData.initial();
  }

  void _initializeSession() {
    _authRepo.authStateChanges.listen((data) async {
      final session = data.session;
      final user = session?.user;

      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (user != null) {
        state = state.copyWith(loading: true);
        final userRepo = ref.read(userRepositoryProvider);
        final profile = await userRepo.getUserProfile(user.id);

        await ref.read(syncManagerProvider).init();

        // Login to OneSignal
        PushNotificationService.login(user.id);

        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          hasProfileSetup: profile != null,
          hasSeenOnboarding: true,
          loading: false,
          error: null,
        );
      } else {
        // Logout from OneSignal
        PushNotificationService.logout();
        state = AuthStateData.initial().copyWith(
          loading: false,
          hasSeenOnboarding: hasSeenOnboarding,
        );
      }
    });
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<String?> signUp(String email, String password, {String? name}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.signUp(email: email, password: password, name: name);
      state = state.copyWith(loading: false, hasSeenOnboarding: true);
      return null;
    } catch (e) {
      final formattedError = _formatAuthError(e);
      state = state.copyWith(error: formattedError, loading: false);
      return formattedError;
    }
  }

  Future<String?> signIn(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.signIn(email: email, password: password);
      state = state.copyWith(loading: false, hasSeenOnboarding: true);
      return null;
    } catch (e) {
      final formattedError = _formatAuthError(e);
      state = state.copyWith(error: formattedError, loading: false);
      return formattedError;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true);
    try {
      await _authRepo.signOut();
    } catch (_) {}
    state = AuthStateData.initial().copyWith(
      loading: false,
      hasSeenOnboarding: true,
    );
  }

  void markProfileSetupComplete() {
    state = state.copyWith(hasProfileSetup: true);
  }

  Future<String?> updatePassword(String newPassword) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.updatePassword(newPassword);
      state = state.copyWith(loading: false);
      return null;
    } catch (e) {
      final formattedError = _formatAuthError(e);
      state = state.copyWith(error: formattedError, loading: false);
      return formattedError;
    }
  }

  Future<String?> deleteAccount() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.deleteAccount();
      state = AuthStateData.initial().copyWith(
        loading: false,
        hasSeenOnboarding: true,
      );
      return null;
    } catch (e) {
      final formattedError = _formatAuthError(e);
      state = state.copyWith(error: formattedError, loading: false);
      return formattedError;
    }
  }

  String _formatAuthError(dynamic error) {
    final message = error.toString().toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials') ||
        message.contains('user not found') ||
        message.contains('wrong password')) {
      return 'Invalid email or password. Please double check your credentials.';
    }

    if (message.contains('user already registered') ||
        message.contains('already exists')) {
      return 'An account with this email address already exists.';
    }

    if (message.contains('password should be at least') ||
        message.contains('weak password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }

    if (message.contains('unable to validate email') ||
        message.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    return error.toString().replaceAll('Exception: ', '');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthStateData>(() {
  return AuthNotifier();
});
