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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const pagePadding = EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      );

                      return SingleChildScrollView(
                        padding: pagePadding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight - pagePadding.vertical,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
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
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                 if (Platform.isIOS) ...[
                                      _buildAuthButton(
                                        isLoading: isLoading,
                                        text: AppStrings.continueWithApple,
                                        backgroundColor: AppColors.white,
                                        foregroundColor: AppColors.black,
                                        borderColor: AppColors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        image: _buildAppleIcon(),
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          context.read<LoginBloc>().add(
                                            const AppleLoginSubmitted(),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 14),
                               ],
                                    _buildAuthButton(
                                      isLoading: isLoading,
                                      text: AppStrings.continueWithGoogle,
                                      backgroundColor: AppColors.white,
                                      foregroundColor: const Color(0xFF1F1F1F),
                                      borderColor: AppColors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      image: _buildGoogleIcon(),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        context.read<LoginBloc>().add(
                                          const GoogleLoginSubmitted(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    _buildDivider(),
                                    const SizedBox(height: 18),
                                    _buildAuthButton(
                                      isLoading: isLoading,
                                      text: AppStrings.continueWithEmail,
                                      backgroundColor: AppColors.white
                                          .withValues(alpha: 0.08),
                                      foregroundColor: AppColors.white,
                                      borderColor: AppColors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      image: _buildEmailIcon(),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        context.goNamed('login');
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthButton({
    required bool isLoading,
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
      ignoring: isLoading,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.6 : 1.0,
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
              textStyle: _authButtonTextStyle.copyWith(
                color: foregroundColor,
              ),
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

  Widget _buildEmailIcon() {
    return _buildIconFrame(
      child: Icon(
        Icons.email_outlined,
        size: _authIconSize - 1,
        color: AppColors.white.withValues(alpha: 0.92),
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
