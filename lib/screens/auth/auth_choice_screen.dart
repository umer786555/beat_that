import 'dart:io' show Platform;

import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_button/sign_in_button.dart';

import 'bloc/login_bloc.dart';
import 'bloc/login_event.dart';
import 'bloc/login_state.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  static const double _primaryActionHeight = 56;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            context.goNamed('home');
          } else if (state is LoginFailure) {
            showErrorSnackBar(context, message: state.error);
          }
        },
        builder: (context, state) {
          final isLoading = state is LoginLoading;

          return Scaffold(
            backgroundColor: AppColors.black,
            body: Stack(
              children: [
                // Subtle background gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.black,
                        AppColors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top spacer
                        const SizedBox(height: 20),

                        // App Icon - slightly smaller for better proportions
                        Center(
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Main Title
                        const Text(
                          AppStrings.beatThat,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: AppColors.electricMagenta,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Subtitle
                        Text(
                          AppStrings.authChoiceSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: 0.3,
                            height: 1.4,
                          ),
                        ),

                        // Middle spacer
                        const SizedBox(height: 30),

                        if (Platform.isIOS) ...[
                          const Text(
                            AppStrings.recommendedForIPhone,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppColors.cyan,
                            ),
                          ),
                          const SizedBox(height: 10),
                          IgnorePointer(
                            ignoring: isLoading,
                            child: AnimatedOpacity(
                              opacity: isLoading ? 0.6 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: SizedBox(
                                height: _primaryActionHeight,
                                child: SignInButton(
                                  Buttons.apple,
                                  text: AppStrings.continueWithApple,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppColors.white,
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    context.read<LoginBloc>().add(
                                      const AppleLoginSubmitted(),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Google Sign In Button - Enhanced Design
                        IgnorePointer(
                          ignoring: isLoading,
                          child: AnimatedOpacity(
                            opacity: isLoading ? 0.6 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: SizedBox(
                              height: _primaryActionHeight,
                              child: SignInButton(
                                Buttons.google,
                                text: AppStrings.continueWithGoogle,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: AppColors.black,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  context.read<LoginBloc>().add(
                                    const GoogleLoginSubmitted(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email Sign In Button - Enhanced Design
                        IgnorePointer(
                          ignoring: isLoading,
                          child: AnimatedOpacity(
                            opacity: isLoading ? 0.6 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: SizedBox(
                              height: _primaryActionHeight,
                              child: SignInButton(
                                Buttons.email,
                                text: AppStrings.continueWithEmail,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: AppColors.black,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  context.goNamed('login');
                                },
                              ),
                            ),
                          ),
                        ),

                        // Bottom spacer
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
