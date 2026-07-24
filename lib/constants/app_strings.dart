/// Centralized strings for the Beat That application
/// All UI strings should be defined here for easy localization and maintenance
class AppStrings {
  // App Name
  static const String beatThat = 'Beat That';

  // Login Screen
  static const String login = 'Login';
  static const String signInToYourAccount = 'Sign in to your account';
  static const String signIn = 'Sign In';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String signUp = 'Sign Up';
  static const String forgotPassword = 'Forgot password?';

  // Signup Screen
  static const String createAccount = 'Create Account';
  static const String joinBeatThatToday = 'Join Beat That today';
  static const String alreadyHaveAccount = 'Already have an account? ';

  // Form Fields - Email
  static const String email = 'Email';
  static const String enterYourEmail = 'Enter your email';

  // Form Fields - Password
  static const String password = 'Password';
  static const String enterYourPassword = 'Enter your password';
  static const String createAPassword = 'Create a password';

  // Form Fields - Confirm Password
  static const String confirmPassword = 'Confirm Password';
  static const String confirmYourPassword = 'Confirm your password';

  // Validation Errors
  static const String pleaseEnterAValidEmail = 'Please enter a valid email';
  static const String passwordMustBeAtLeast6Characters =
      'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';

  // Login Errors
  static const String invalidEmailOrPassword = 'Invalid email or password';
  static const String pleaseConfirmYourEmailBeforeLoggingIn =
      'Please confirm your email before logging in';
  static const String userNotFoundPleaseSignUpFirst =
      'User not found. Please sign up first';
  static const String loginFailedPleaseTryAgain =
      'Login failed. Please try again';

  // Signup Errors
  static const String thisEmailIsAlreadyRegisteredPleaseSignInInstead =
      'This email is already registered. Please sign in instead.';
  static const String pleaseEnterAValidEmailAddress =
      'Please enter a valid email address';
  static const String confirmationEmailCouldNotBeSent =
      'We could not send the confirmation email right now. Please try again later.';
  static const String signupFailedPleaseTryAgain =
      'Signup failed. Please try again';

  // Network Errors
  static const String networkErrorPleaseCheckYourConnection =
      'Network error. Please check your connection';

  // Success Messages
  static const String accountCreatedSuccessfullyPleaseCheckYourEmailToConfirm =
      'Account created successfully! Please check your email to confirm.';

  // Profile Screen
  static const String failedToLoadProfile = 'Failed to load profile';
  static const String failedToChangeTheme = 'Failed to change theme';
  static const String logoutFailed = 'Logout failed';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String darkTheme = 'Dark theme';
  static const String darkThemeDescription =
      'Switch between the light and dark app themes.';
  static const String deleteAccount = 'Delete account';
  static const String deleteAccountDescription =
      'Permanently remove your account and everything tied to it.';
  static const String deleteAccountDialogTitle = 'Delete account?';
  static const String deleteAccountDialogMessage =
      'This permanently deletes your ratings, followers, following, uploaded videos, and profile data. This can\'t be undone.';
  static const String deleteAccountFailed = 'Delete account failed';
  static const String logOut = 'Log out';
  static const String logOutDescription =
      'Sign out of your account on this device.';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String recordVideo = 'Record Video';

  // Camera Permission Strings
  static const String cameraAccessRequired = 'Camera Access Required';
  static const String cameraPermissionBody =
      'To record videos, we need access to your camera. Please enable camera permissions in app settings.';
  static const String openSettings = 'Open Settings';
}
