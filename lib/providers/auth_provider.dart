import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/data/repositories/auth_repository.dart';

class AuthStateData {
  final bool isAuthenticated;
  final User? user;
  final bool loading;
  final String? error;

  AuthStateData({
    required this.isAuthenticated,
    required this.user,
    required this.loading,
    required this.error,
  });

  factory AuthStateData.initial() => AuthStateData(
        isAuthenticated: false,
        user: null,
        loading: true,
        error: null,
      );

  AuthStateData copyWith({
    bool? isAuthenticated,
    User? user,
    bool? loading,
    String? error,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthStateData> {
  late final AuthRepository _authRepo;

  @override
  AuthStateData build() {
    _authRepo = ref.watch(authRepositoryProvider);
    // Use Future.microtask to avoid modifying providers during build phase
    Future.microtask(() => _initializeSession());
    return AuthStateData.initial();
  }

  void _initializeSession() {
    _authRepo.authStateChanges.listen((data) {
      final session = data.session;
      final user = session?.user;

      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
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
}

final authProvider = NotifierProvider<AuthNotifier, AuthStateData>(() {
  return AuthNotifier();
});
