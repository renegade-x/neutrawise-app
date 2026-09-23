import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/widgets/modals/error_popup.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? resetToken;

  const ResetPasswordScreen({super.key, this.resetToken});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String password) {
    // At least 8 chars, 1 uppercase, 1 lowercase, 1 number
    final hasMinLength = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    return hasMinLength && hasUpper && hasLower && hasDigit;
  }

  Future<void> _handleResetPassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Edge case: Empty passwords
    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in both password fields.';
        _successMessage = null;
      });
      return;
    }

    // Edge case: Passwords don't match
    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _successMessage = null;
      });
      return;
    }

    // Edge case: Password too weak
    if (!_isStrongPassword(password)) {
      setState(() {
        _errorMessage =
            'Please ensure your password meets all requirements below.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .updatePassword(password);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        final errLower = error.toLowerCase();
        if (errLower.contains('token expired') ||
            errLower.contains('invalid token') ||
            errLower.contains('invalid signature')) {
          _errorMessage =
              'This reset link has expired or is invalid. Please request a new one.';
          ErrorPopup.show(
            context,
            title: 'Link Expired',
            message:
                'This reset link has expired or is invalid. Please request a new one.',
          );
        } else if (errLower.contains('password should be different') ||
            errLower.contains('same password')) {
          _errorMessage =
              'New password must be different from your previous password.';
          ErrorPopup.show(
            context,
            title: 'Invalid Password',
            message:
                'New password must be different from your previous password.',
          );
        } else {
          _errorMessage = error;
          ErrorPopup.showFromException(context, error);
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _successMessage =
            'Password reset successfully! Redirecting to Log In...';
      });

      // Redirect after brief delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          try {
            context.go('/login');
          } catch (_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordText = _passwordController.text;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Create New Password',
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
                'Reset Your Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a strong new password for your NeutraWise account.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 24),

              // New Password Field
              TextField(
                controller: _passwordController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary(context),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textSecondary(context),
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                  enabled: !_isLoading,
                ),
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Confirm Password Field
              TextField(
                controller: _confirmPasswordController,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary(context),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppColors.textSecondary(context),
                    ),
                    onPressed: () {
                      setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      );
                    },
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGreen),
                  ),
                  enabled: !_isLoading,
                ),
                obscureText: !_showConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleResetPassword(),
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

              // Submit Button
              PrimaryButton(
                text: 'Reset Password',
                onPressed: _handleResetPassword,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 24),

              // Password Requirements Checklist Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.security,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Password Requirements:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PasswordRequirementRow(
                      label: 'At least 8 characters',
                      met: passwordText.length >= 8,
                    ),
                    _PasswordRequirementRow(
                      label: 'Contains uppercase letter (A-Z)',
                      met: passwordText.contains(RegExp(r'[A-Z]')),
                    ),
                    _PasswordRequirementRow(
                      label: 'Contains lowercase letter (a-z)',
                      met: passwordText.contains(RegExp(r'[a-z]')),
                    ),
                    _PasswordRequirementRow(
                      label: 'Contains number (0-9)',
                      met: passwordText.contains(RegExp(r'[0-9]')),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Back to login link
              Center(
                child: TextButton(
                  onPressed: () {
                    try {
                      context.go('/login');
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _PasswordRequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? AppColors.success : AppColors.textSecondary(context),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met
                  ? AppColors.textPrimary(context)
                  : AppColors.textSecondary(context),
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
