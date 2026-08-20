import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      showErrorSnackBar(
        context,
        message: AppStrings.passwordMustBeAtLeast6Characters,
      );
      return;
    }

    if (password != confirmPassword) {
      showErrorSnackBar(context, message: AppStrings.passwordsDoNotMatch);
      return;
    }

    if (!locator<AuthService>().isLoggedIn()) {
      showErrorSnackBar(
        context,
        message: AppStrings.resetPasswordFailedPleaseTryAgain,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await locator<AuthService>().updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) {
        return;
      }

      showSuccessSnackBar(
        context,
        message: AppStrings.passwordUpdatedSuccessfully,
      );
      context.goNamed('home');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final errorText = error.toString();
      final message = errorText.contains('Network')
          ? AppStrings.networkErrorPleaseCheckYourConnection
          : AppStrings.resetPasswordFailedPleaseTryAgain;
      showErrorSnackBar(context, message: message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        centerTitle: true,
        title: Text(
          AppStrings.chooseNewPassword,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.white,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/icon/app_icon.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.resetPasswordSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _passwordController,
                cursorColor: AppColors.cyan,
                enabled: !_isSubmitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: AppStrings.createAPassword,
                  labelText: AppStrings.password,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.electricMagenta,
                      size: 20,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                cursorColor: AppColors.cyan,
                enabled: !_isSubmitting,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSubmitting) {
                    HapticFeedback.mediumImpact();
                    _submit();
                  }
                },
                decoration: InputDecoration(
                  hintText: AppStrings.confirmYourPassword,
                  labelText: AppStrings.confirmPassword,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.electricMagenta,
                      size: 20,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        _submit();
                      },
                style: getAuthElevatedButtonStyle(),
                child: _isSubmitting
                    ? getAuthLoadingSpinner()
                    : const Text(
                        AppStrings.updatePassword,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.white,
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
