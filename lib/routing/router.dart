import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/features/auth/screens/onboarding_screen.dart';
import 'package:neutrawise/features/auth/screens/login_screen.dart';
import 'package:neutrawise/features/auth/screens/signup_screen.dart';
import 'package:neutrawise/features/auth/screens/profile_setup_screen.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';
import 'package:neutrawise/features/auth/screens/loading_splash_screen.dart';

class AuthRefreshListenable extends ChangeNotifier {
  final Ref _ref;

  AuthRefreshListenable(this._ref) {
    _ref.listen(authProvider, (_, state) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.loading) {
        if (state.uri.path == '/') return null;
        return '/'; // Go to loading splash screen while checking session
      }

      final isAuth = authState.isAuthenticated;
      final isLoggingIn =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/onboarding';

      if (!isAuth) {
        if (isLoggingIn) return null;
        return '/login';
      }

      // If authenticated
      if (!authState.hasProfileSetup) {
        if (state.uri.path != '/profile-setup') return '/profile-setup';
        return null;
      }

      // If authenticated and profile is setup
      if (isLoggingIn ||
          state.uri.path == '/profile-setup' ||
          state.uri.path == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoadingSplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
