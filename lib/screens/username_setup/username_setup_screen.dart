import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/auth/widgets/auth_legal_consent_section.dart';
import 'package:beat_that/screens/username_setup/bloc/username_setup_bloc.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/auth_button_styles.dart';

/// Full-screen username setup screen for new users
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  late final TextEditingController _usernameController;
  late final bool _requiresLegalAcceptance;
  bool _hasAcceptedLegal = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _requiresLegalAcceptance =
        !locator<AuthService>().hasAcceptedCurrentLegalVersion();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _handleContinue(BuildContext context) {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    context.read<UsernameSetupBloc>().add(
      SaveUsernameEvent(
        username: username,
        hasAcceptedLegal: !_requiresLegalAcceptance || _hasAcceptedLegal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UsernameSetupBloc(),
      child:
          BlocPresentationListener<
            UsernameSetupBloc,
            UsernameSetupPresentationEvent
          >(
            listener: (context, event) {
              switch (event) {
                case UsernameSetupSuccessEvent():
                  context.go('/home');
                case UsernameSetupErrorEvent():
                  showErrorSnackBar(context, message: event.message);
              }
            },
            child: Scaffold(
              body: BlocBuilder<UsernameSetupBloc, UsernameSetupState>(
                builder: (context, state) {
                  final isLoading = state is UsernameSetupLoading;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 60),
                          const Icon(
                            Icons.person_add,
                            color: AppColors.cyan,
                            size: 60,
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            AppStrings.createYourUsername,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            AppStrings.chooseAUniqueUsernameToGetStarted,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.white,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          TextField(
                            cursorColor: AppColors.cyan,
                            controller: _usernameController,
                            enabled: !isLoading,

                           // style: getAuthTextFormFieldStyle(),
                            decoration: InputDecoration(
                              hintText: AppStrings.enterYourUsername,
                              labelText: AppStrings.username,
                              prefixIcon: Icon(
                                Icons.person,
                                color: AppColors.cyan,
                                size: 20,
                              ),
                            ),
                          ),
                          if (_requiresLegalAcceptance) ...[
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
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: isLoading ||
                                    (_requiresLegalAcceptance &&
                                        !_hasAcceptedLegal)
                                ? null
                                : () => _handleContinue(context),
                            style: getAuthElevatedButtonStyle(),
                            child: isLoading
                                ? getAuthLoadingSpinner()
                                : const Text(
                                    AppStrings.continueAction,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }
}
