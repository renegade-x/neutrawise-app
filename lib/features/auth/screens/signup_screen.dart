import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showErrorDialog(
        'Invalid Input Format',
        'Please enter a valid email address (e.g. user@example.com).',
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
      _showErrorDialog('Sign Up Failed', errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  'assets/images/logo.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondaryDark,
                  ),
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. London, New York, Tokyo',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.location_city_outlined,
                    color: AppColors.textSecondaryDark,
                  ),
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.streetAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.textSecondaryDark,
                  ),
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondaryDark,
                  ),
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
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
