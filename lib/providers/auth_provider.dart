import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/data/repositories/auth_repository.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/sync/sync_manager.dart';

class AuthStateData {
  final bool isAuthenticated;
  final User? user;
  final bool loading;
  final String? error;
  final bool hasProfileSetup;

  AuthStateData({
    required this.isAuthenticated,
    required this.user,
    required this.loading,
    required this.error,
    required this.hasProfileSetup,
  });

  factory AuthStateData.initial() => AuthStateData(
    isAuthenticated: false,
    user: null,
    loading: true,
    error: null,
    hasProfileSetup: false,
  );

  AuthStateData copyWith({
    bool? isAuthenticated,
    User? user,
    bool? loading,
    String? error,
    bool? hasProfileSetup,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
      hasProfileSetup: hasProfileSetup ?? this.hasProfileSetup,
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

      if (user != null) {
        state = state.copyWith(loading: true);
        final userRepo = ref.read(userRepositoryProvider);
        final profile = await userRepo.getUserProfile(user.id);

        await ref.read(syncManagerProvider).init();

        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          hasProfileSetup: profile != null,
          loading: false,
          error: null,
        );
      } else {
        state = AuthStateData.initial().copyWith(loading: false);
      }
    });
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.signUp(email: email, password: password);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.signIn(email: email, password: password);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.signOut();
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  void markProfileSetupComplete() {
    state = state.copyWith(hasProfileSetup: true);
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.updatePassword(newPassword);
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepo.deleteAccount();
      state = state.copyWith(
        loading: false,
        isAuthenticated: false,
        user: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthStateData>(() {
  return AuthNotifier();
});
