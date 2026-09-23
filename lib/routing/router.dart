import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/features/auth/screens/onboarding_screen.dart';
import 'package:neutrawise/features/auth/screens/login_screen.dart';
import 'package:neutrawise/features/auth/screens/signup_screen.dart';
import 'package:neutrawise/features/auth/screens/forgot_password_screen.dart';
import 'package:neutrawise/features/auth/screens/reset_password_screen.dart';
import 'package:neutrawise/features/auth/screens/profile_setup_screen.dart';
import 'package:neutrawise/features/profile/screens/notification_preferences_screen.dart';
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

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final hasSeenOnboarding = authState.hasSeenOnboarding;
      final isAuthFlow =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/onboarding' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/reset-password';

      // Always allow reset-password route during password recovery flows
      if (state.uri.path == '/reset-password') {
        return null;
      }

      if (authState.loading) {
        // While checking initial session on startup (at '/'), stay on '/'
        // If already in an auth flow (user tapped Log In/Sign Up), stay on screen to show button spinner
        if (state.uri.path == '/' || isAuthFlow) return null;
        return '/'; // Go to loading splash screen while checking initial session
      }

      if (!isAuth) {
        if (!hasSeenOnboarding) {
          if (state.uri.path == '/onboarding') return null;
          return '/onboarding';
        }
        if (isAuthFlow) return null;
        return '/login';
      }

      // If authenticated
      if (!authState.hasProfileSetup) {
        if (state.uri.path != '/profile-setup') return '/profile-setup';
        return null;
      }

      // If authenticated and profile is setup
      if (isAuthFlow || state.uri.path == '/') {
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(resetToken: token);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/notification-preferences',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
