import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

import 'package:neutrawise/widgets/modals/error_popup.dart';

import 'package:neutrawise/widgets/buttons/google_sign_in_button.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
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
    _nameController.dispose();
    _cityController.dispose();
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

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty && city.isEmpty && email.isEmpty && password.isEmpty) {
      _showErrorDialog(
        'Empty Fields',
        'Please fill in all fields (Full Name, City, Email, and Password).',
      );
      return;
    }

    if (name.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter your full name.');
      return;
    }

    if (city.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter your city.');
      return;
    }

    if (email.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog('Empty Field', 'Please enter a password.');
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

    if (password.length < 6) {
      _showErrorDialog(
        'Invalid Input Format',
        'Password must be at least 6 characters long.',
      );
      return;
    }

    final errorMsg = await ref
        .read(authProvider.notifier)
        .signUp(email, password, name: name, city: city);

    if (errorMsg != null && mounted) {
      ErrorPopup.showFromException(context, errorMsg);
    }
  }

  Future<void> _signUpWithGoogle() async {
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
          'Sign Up',
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
                controller: _nameController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary(context),
                  ),
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. London, New York, Tokyo',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary(
                      context,
                    ).withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.location_city_outlined,
                    color: AppColors.textSecondary(context),
                  ),
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.streetAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.textSecondary(context),
                  ),
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
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary(context),
                  ),
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
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Sign Up',
                onPressed: _signUp,
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
                text: 'Sign up with Google',
                onPressed: _signUpWithGoogle,
                isLoading: authState.loading,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/login'),
                child: const Text(
                  'Already have an account? Log In',
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
