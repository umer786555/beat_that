import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      showErrorSnackBar(context, message: AppStrings.pleaseEnterAValidEmail);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await locator<AuthService>().resetPassword(
        email: email,
        redirectTo: AuthService.authCallbackUrl,
      );

      if (!mounted) {
        return;
      }

      showSuccessSnackBar(context, message: AppStrings.resetPasswordEmailSent);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final errorText = error.toString();
      final message = errorText.contains('Network')
          ? AppStrings.networkErrorPleaseCheckYourConnection
          : AppStrings.loginFailedPleaseTryAgain;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 24),
          onPressed: _isSubmitting
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed('login');
                  }
                },
        ),
        title: Text(
          AppStrings.forgotPasswordTitle,
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
                AppStrings.forgotPasswordSubtitle,
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
                controller: _emailController,
                cursorColor: AppColors.cyan,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSubmitting) {
                    HapticFeedback.mediumImpact();
                    _submit();
                  }
                },
                decoration: const InputDecoration(
                  hintText: AppStrings.enterYourEmail,
                  labelText: AppStrings.email,
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
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
                        AppStrings.sendResetLink,
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
