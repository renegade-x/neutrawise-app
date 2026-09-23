import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

import 'package:neutrawise/widgets/modals/error_popup.dart';

import 'package:neutrawise/widgets/buttons/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).clearLoading();
    }
  }

  void _showErrorDialog(String title, String message) {
    ErrorPopup.show(context, title: title, message: message);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty && password.isEmpty) {
      _showErrorDialog(
        'Empty Fields',
        'Please enter both your email address and password.',
      );
      return;
    }

    if (email.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter your password.');
      return;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      ErrorPopup.showInvalidEmail(
        context,
        message: 'Please enter a valid email address (e.g. user@example.com).',
      );
      return;
    }

    final errorMsg = await ref
        .read(authProvider.notifier)
        .signIn(email, password);
    if (errorMsg != null && mounted) {
      ErrorPopup.showFromException(context, errorMsg);
    }
  }

  Future<void> _loginWithGoogle() async {
    final errorMsg = await ref.read(authProvider.notifier).signInWithGoogle();
    if (errorMsg != null && mounted) {
      ErrorPopup.showFromException(context, errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Log In',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  AppColors.logo(context),
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Log In',
                onPressed: _login,
                isLoading: authState.loading,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.divider(context))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.divider(context))),
                ],
              ),
              const SizedBox(height: 20),
              GoogleSignInButton(
                text: 'Sign in with Google',
                onPressed: _loginWithGoogle,
                isLoading: authState.loading,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/signup'),
                child: const Text(
                  'Don\'t have an account? Sign Up',
                  style: TextStyle(color: AppColors.primaryGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
