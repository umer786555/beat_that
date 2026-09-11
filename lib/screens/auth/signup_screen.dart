import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/screens/auth/widgets/auth_legal_consent_section.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'bloc/signup_bloc.dart';
import 'bloc/signup_event.dart';
import 'bloc/signup_state.dart';

/// Signup screen for new users to create an account
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _hasAcceptedLegal = false;

  static const double _primaryActionHeight = 54;
  static const double _primaryActionRadius = 8;
  static const double _authIconSize = 28;
  static const double _authIconBoxSize = 34;
  static const TextStyle _authButtonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SignupBloc(),
      child: BlocConsumer<SignupBloc, SignupState>(
        listener: (context, state) {
          // Handle navigation and error messages
          if (state is SignupSuccess) {
            // Show success message
            showSuccessSnackBar(
              context,
              message: AppStrings
                  .accountCreatedSuccessfullyPleaseCheckYourEmailToConfirm,
            );

            // Navigate to login
            if (context.mounted) {
              context.goNamed('login');
            }
          } else if (state is SignupAuthenticatedSuccess) {
            if (context.mounted) {
              context.goNamed('home');
            }
          } else if (state is SignupFailure) {
            // Show error snack bar
            showErrorSnackBar(context, message: state.error);
          }
        },
        builder: (context, state) {
          final isLoading = state is SignupLoading;
          final formState = state is SignupFormUpdated ? state : null;
          final email = formState?.email ?? '';
          final password = formState?.password ?? '';
          final confirmPassword = formState?.confirmPassword ?? '';
          final obscurePassword = formState?.obscurePassword ?? true;
          final obscureConfirmPassword =
              formState?.obscureConfirmPassword ?? true;

          return Scaffold(
            backgroundColor: AppColors.black,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        context.goNamed('auth');
                      },
              ),
              title: Text(
                AppStrings.signUp,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const SizedBox(height: 24),
                    // Header
                    Image.asset(
                      'assets/icon/app_icon.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    const Text(
                      AppStrings.beatThat,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.electricMagenta,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.joinBeatThatToday,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email field
                    TextFormField(
                      cursorColor: AppColors.cyan,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        context.read<SignupBloc>().add(
                          EmailChanged(email: value),
                        );
                      },
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      initialValue: email,
                      //style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.enterYourEmail,
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      cursorColor: AppColors.cyan,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        context.read<SignupBloc>().add(
                          PasswordChanged(password: value),
                        );
                      },
                      enabled: !isLoading,
                      obscureText: obscurePassword,
                      initialValue: password,
                      //style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.createAPassword,
                        labelText: AppStrings.password,
                        prefixIcon: Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.electricMagenta,
                            size: 20,
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  context.read<SignupBloc>().add(
                                    const PasswordVisibilityToggled(),
                                  );
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password field
                    TextFormField(
                      cursorColor: AppColors.cyan,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        context.read<SignupBloc>().add(
                          ConfirmPasswordChanged(confirmPassword: value),
                        );
                      },
                      enabled: !isLoading,
                      obscureText: obscureConfirmPassword,
                      initialValue: confirmPassword,
                      //style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.confirmYourPassword,
                        labelText: AppStrings.confirmPassword,
                        prefixIcon: Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  context.read<SignupBloc>().add(
                                    const ConfirmPasswordVisibilityToggled(),
                                  );
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    AuthLegalConsentSection(
                      value: _hasAcceptedLegal,
                      enabled: !isLoading,
                      onChanged: (value) {
                        setState(() {
                          _hasAcceptedLegal = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    if (Platform.isIOS) ...[
                      _buildSocialAuthButton(
                        isLoading: isLoading,
                        isEnabled: _hasAcceptedLegal,
                        text: AppStrings.continueWithApple,
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                        borderColor: AppColors.white.withValues(alpha: 0.14),
                        image: _buildAppleIcon(),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.read<SignupBloc>().add(
                            AppleSignupSubmitted(
                              hasAcceptedLegal: _hasAcceptedLegal,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildSocialAuthButton(
                      isLoading: isLoading,
                      isEnabled: _hasAcceptedLegal,
                      text: AppStrings.continueWithGoogle,
                      backgroundColor: AppColors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                      borderColor: AppColors.white.withValues(alpha: 0.14),
                      image: _buildGoogleIcon(),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.read<SignupBloc>().add(
                          GoogleSignupSubmitted(
                            hasAcceptedLegal: _hasAcceptedLegal,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildDivider(),
                    const SizedBox(height: 18),

                    // Signup button
                    ElevatedButton(
                      onPressed: isLoading || !_hasAcceptedLegal
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              context.read<SignupBloc>().add(
                                SignupSubmitted(
                                  hasAcceptedLegal: _hasAcceptedLegal,
                                ),
                              );
                            },
                      style: getAuthElevatedButtonStyle(),
                      child: isLoading
                          ? getAuthLoadingSpinner()
                          : const Text(
                              AppStrings.createAccount,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          AppStrings.alreadyHaveAccount,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  context.goNamed('login');
                                },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              AppStrings.signIn,
                              style: TextStyle(
                                color: isLoading
                                    ? AppColors.white
                                    : AppColors.cyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialAuthButton({
    required bool isLoading,
    required bool isEnabled,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
    Widget? image,
    required VoidCallback onPressed,
    Color? borderColor,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_primaryActionRadius),
      side: BorderSide(color: borderColor ?? Colors.transparent),
    );

    return IgnorePointer(
      ignoring: isLoading || !isEnabled,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.6 : (isEnabled ? 1.0 : 0.45),
        duration: const Duration(milliseconds: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_primaryActionRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SizedBox(
            height: _primaryActionHeight,
            width: double.infinity,
            child: SignInButtonBuilder(
              text: text,
              onPressed: onPressed,
              backgroundColor: backgroundColor,
              image: image,
              padding: EdgeInsets.zero,
              innerPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: shape,
              elevation: 0,
              height: _primaryActionHeight,
              width: double.infinity,
              splashColor: foregroundColor.withValues(alpha: 0.08),
              highlightColor: foregroundColor.withValues(alpha: 0.05),
              textStyle: _authButtonTextStyle.copyWith(color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconFrame({required Widget child}) {
    return SizedBox(
      width: _authIconBoxSize,
      height: _authIconBoxSize,
      child: Center(
        child: FittedBox(fit: BoxFit.contain, child: child),
      ),
    );
  }

  Widget _buildAppleIcon() {
    return _buildIconFrame(
      child: const Icon(
        Icons.apple,
        size: _authIconSize - 1,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return _buildIconFrame(
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: 0.78,
          heightFactor: 0.78,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/logos/google_light.png',
              package: 'sign_in_button',
              width: _authIconSize * 1.9,
              height: _authIconSize * 1.9,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.white.withValues(alpha: 0.14),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.white.withValues(alpha: 0.14),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
