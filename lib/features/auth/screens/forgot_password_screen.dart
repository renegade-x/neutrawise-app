import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

import 'package:neutrawise/widgets/modals/error_popup.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    // Edge case: Empty email
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
        _successMessage = null;
      });
      return;
    }

    // Edge case: Invalid email format
    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage =
            'Please enter a valid email address (e.g. user@example.com).';
        _successMessage = null;
      });
      ErrorPopup.showInvalidEmail(
        context,
        message: 'Please enter a valid email address (e.g. user@example.com).',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .resetPasswordForEmail(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (error != null) {
        // Check for specific Supabase error types or user not found
        final errLower = error.toLowerCase();
        if (errLower.contains('user not found') ||
            errLower.contains('invalid user')) {
          // Security best practice: Don't reveal if email exists
          _successMessage =
              'If an account exists with this email, a password reset link has been sent.';
          _errorMessage = null;
        } else if (errLower.contains('rate limit') ||
            errLower.contains('over_email_send_rate_limit')) {
          _errorMessage =
              'Too many reset requests. Please try again in 5 minutes.';
          ErrorPopup.showTooManyRequests(
            context,
            message: 'Too many reset requests. Please try again in 5 minutes.',
          );
        } else {
          _errorMessage = error;
          ErrorPopup.showFromException(context, error);
        }
      } else {
        _successMessage =
            'Password reset link sent! Check your inbox (and spam folder).';
        _emailController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            try {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            } catch (_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  AppColors.logo(context),
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Forgot your password?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your registered email address and we will send you a secure link to reset your password.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 24),

              // Email input
              TextField(
                controller: _emailController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                  enabled: !_isLoading,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleForgotPassword(),
              ),

              const SizedBox(height: 16),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Success banner
              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              PrimaryButton(
                text: 'Send Reset Link',
                onPressed: _handleForgotPassword,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Back to login link
              TextButton(
                onPressed: () {
                  try {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  } catch (_) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                child: const Text(
                  'Back to Log In',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tips container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Helpful Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Check your spam or junk folder if you don\'t receive the email within a minute.\n'
                      '• The password reset link expires in 1 hour for your security.\n'
                      '• You can request a new link at any time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
