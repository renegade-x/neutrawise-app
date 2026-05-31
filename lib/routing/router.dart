import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/features/auth/screens/onboarding_screen.dart';
import 'package:neutrawise/features/auth/screens/login_screen.dart';
import 'package:neutrawise/features/auth/screens/signup_screen.dart';
import 'package:neutrawise/features/auth/screens/profile_setup_screen.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.uri.path == '/login' || state.uri.path == '/signup' || state.uri.path == '/onboarding';

      if (!isAuth && !isLoggingIn) return '/onboarding';
      
      if (isAuth && isLoggingIn) {
        // Here we ideally check if profile setup is complete
        // For now, redirect to dashboard
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/onboarding',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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
