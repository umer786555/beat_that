import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/form_input_decoration.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';
import 'bloc/signup_bloc.dart';
import 'bloc/signup_event.dart';
import 'bloc/signup_state.dart';

/// Signup screen for new users to create an account
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

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
              title: const Text(AppStrings.signUp),
              elevation: 0,
              centerTitle: true,
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
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
                      style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.enterYourEmail,
                        labelText: AppStrings.email,
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          size: 20,
                        ),
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
                      style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.createAPassword,
                        labelText: AppStrings.password,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          size: 20,
                        ),
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
                      style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.confirmYourPassword,
                        labelText: AppStrings.confirmPassword,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          size: 20,
                        ),
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

                    // Signup button
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              context.read<SignupBloc>().add(
                                const SignupSubmitted(),
                              );
                            },
                      style: getAuthElevatedButtonStyle(),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
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
                    const SizedBox(height: 16),

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
}
