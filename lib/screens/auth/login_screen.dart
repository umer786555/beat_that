import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';
import 'bloc/login_bloc.dart';
import 'bloc/login_event.dart';
import 'bloc/login_state.dart';

/// Login screen for existing users to sign in
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          // Handle navigation and error messages
          if (state is LoginSuccess) {
            // Navigate to home on successful login
            context.goNamed('home');
          } else if (state is LoginFailure) {
            // Show error snack bar
            showErrorSnackBar(context, message: state.error);
          }
        },
        builder: (context, state) {
          final isLoading = state is LoginLoading;
          final formState = state is LoginFormUpdated ? state : null;
          final email = formState?.email ?? '';
          final password = formState?.password ?? '';
          final obscurePassword = formState?.obscurePassword ?? true;

          return Scaffold(
            backgroundColor: AppColors.black,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                onPressed: isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        context.goNamed('auth');
                      },
              ),
              title: Text(
                AppStrings.login,
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
                      AppStrings.signInToYourAccount,
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
                        context.read<LoginBloc>().add(
                          EmailChanged(email: value),
                        );
                      },
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      initialValue: email,
                      //  style: getAuthTextFormFieldStyle(),
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
                        context.read<LoginBloc>().add(
                          PasswordChanged(password: value),
                        );
                      },
                      enabled: !isLoading,
                      obscureText: obscurePassword,
                      initialValue: password,
                      //style: getAuthTextFormFieldStyle(),
                      decoration: InputDecoration(
                        hintText: AppStrings.enterYourPassword,
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
                                  context.read<LoginBloc>().add(
                                    const PasswordVisibilityToggled(),
                                  );
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              context.read<LoginBloc>().add(
                                LoginSubmitted(
                                  email: email,
                                  password: password,
                                ),
                              );
                            },
                      style: getAuthElevatedButtonStyle(),
                      child: isLoading
                          ? getAuthLoadingSpinner()
                          : const Text(
                              AppStrings.signIn,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Forgot password link
                    Center(
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                final trimmedEmail = email.trim();
                                if (trimmedEmail.isEmpty) {
                                  context.pushNamed('forgot-password');
                                } else {
                                  context.pushNamed(
                                    'forgot-password',
                                    queryParameters: {'email': trimmedEmail},
                                  );
                                }
                              },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            AppStrings.forgotPassword,
                            style: TextStyle(
                              color: isLoading
                                  ? AppColors.white
                                  : AppColors.cyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          AppStrings.dontHaveAccount,
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
                                  context.goNamed('signup');
                                },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              AppStrings.signUp,
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
