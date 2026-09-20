import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/username_setup/bloc/username_setup_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
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
      SaveUsernameEvent(username: username),
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
                            AppStrings.chooseYourUsername,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
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

                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: isLoading
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
