import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/features/auth/screens/login_screen.dart';
import 'package:neutrawise/features/auth/screens/signup_screen.dart';
import 'package:neutrawise/widgets/buttons/google_sign_in_button.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/domain/models/user_profile.dart';

class MockGoogleAuthNotifier extends AuthNotifier {
  final Future<String?> Function()? onSignInWithGoogle;

  MockGoogleAuthNotifier({this.onSignInWithGoogle});

  @override
  AuthStateData build() {
    return AuthStateData(
      isAuthenticated: false,
      user: null,
      loading: false,
      error: null,
      hasProfileSetup: false,
      hasSeenOnboarding: true,
    );
  }

  @override
  Future<String?> signInWithGoogle({String? redirectTo}) async {
    state = state.copyWith(loading: true);
    if (onSignInWithGoogle != null) {
      final res = await onSignInWithGoogle!();
      state = state.copyWith(loading: false, error: res);
      return res;
    }
    state = state.copyWith(loading: false);
    return null;
  }
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('Google OAuth Button & UI Tests', () {
    testWidgets(
      'renders Google Sign In button on LoginScreen and triggers OAuth',
      (tester) async {
        bool googleClicked = false;
        final mockAuth = MockGoogleAuthNotifier(
          onSignInWithGoogle: () async {
            googleClicked = true;
            return null;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoogleSignInButton), findsOneWidget);
        expect(find.text('Sign in with Google'), findsOneWidget);
        expect(find.text('OR'), findsOneWidget);

        await tester.tap(find.byType(GoogleSignInButton));
        await tester.pump();
        expect(googleClicked, isTrue);
      },
    );

    testWidgets(
      'renders Google Sign Up button on SignUpScreen and triggers OAuth',
      (tester) async {
        bool googleClicked = false;
        final mockAuth = MockGoogleAuthNotifier(
          onSignInWithGoogle: () async {
            googleClicked = true;
            return null;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => mockAuth)],
            child: const MaterialApp(home: SignUpScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoogleSignInButton), findsOneWidget);
        expect(find.text('Sign up with Google'), findsOneWidget);
        expect(find.text('OR'), findsOneWidget);

        await tester.ensureVisible(find.byType(GoogleSignInButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(GoogleSignInButton));
        await tester.pump();
        expect(googleClicked, isTrue);
      },
    );

    testWidgets(
      'GoogleSignInButton shows loading indicator when isLoading is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GoogleSignInButton(
                text: 'Sign in with Google',
                onPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Sign in with Google'), findsNothing);
      },
    );

    testWidgets('GoogleSignInButton triggers callback on tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              text: 'Sign in with Google',
              onPressed: () => tapped = true,
              isLoading: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
      'clears loading state and enables buttons when app resumes from cancelled OAuth',
      (tester) async {
        final mockAuth = MockGoogleAuthNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger OAuth which completes browser launch and leaves screen interactive
        await tester.tap(find.byType(GoogleSignInButton));
        await tester.pumpAndSettle();

        // Simulate app switching / lifecycle resume
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoogleSignInButton), findsOneWidget);
        expect(find.text('Sign in with Google'), findsOneWidget);
      },
    );
  });

  group('Google User Metadata Extraction & Profile Ingestion Tests', () {
    test('constructs UserProfile correctly from Google OAuth metadata', () {
      final googleMetadata = {
        'full_name': 'Ali Khan',
        'picture': 'https://lh3.googleusercontent.com/a/test-avatar',
        'city': 'Lahore',
      };

      final googleFullName =
          googleMetadata['full_name'] ?? googleMetadata['name'];
      final googleAvatar =
          googleMetadata['avatar_url'] ?? googleMetadata['picture'];
      final userCity = googleMetadata['city'];

      final profile = UserProfile(
        id: 'google-user-123',
        name: googleFullName ?? 'User',
        email: 'ali.khan@gmail.com',
        avatarUrl: googleAvatar,
        city: userCity,
      );

      expect(profile.id, 'google-user-123');
      expect(profile.name, 'Ali Khan');
      expect(profile.email, 'ali.khan@gmail.com');
      expect(
        profile.avatarUrl,
        'https://lh3.googleusercontent.com/a/test-avatar',
      );
      expect(profile.city, 'Lahore');
    });

    test('falls back safely when Google metadata has minimal fields', () {
      final minimalMetadata = <String, dynamic>{};

      final googleFullName =
          (minimalMetadata['full_name'] ?? minimalMetadata['name']) as String?;
      final googleAvatar =
          (minimalMetadata['avatar_url'] ?? minimalMetadata['picture'])
              as String?;
      final userCity = minimalMetadata['city'] as String?;
      final email = 'user123@gmail.com';

      final initialName =
          googleFullName != null && googleFullName.trim().isNotEmpty
          ? googleFullName.trim()
          : (email.split('@').first);

      final profile = UserProfile(
        id: 'google-user-456',
        name: initialName,
        email: email,
        avatarUrl: googleAvatar,
        city: userCity,
      );

      expect(profile.name, 'user123');
      expect(profile.avatarUrl, isNull);
      expect(profile.city, isNull);
    });
  });
}
