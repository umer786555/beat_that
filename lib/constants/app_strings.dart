/// Centralized strings for the Beat That application
/// All UI strings should be defined here for easy localization and maintenance
class AppStrings {
  // App Name
  static const String beatThat = 'Beat That';

  // Login Screen
  static const String login = 'Login';
  static const String signInToYourAccount = 'Sign in to your account';
  static const String signIn = 'Sign In';
  static const String recommendedForIPhone = 'Recommended for iPhone';
  static const String continueWithApple = 'Continue with Apple';
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithEmail = 'Continue with Email';
  static const String authChoiceSubtitle =
      'Share your game, rate the competition, and get back to the action fast.';
  static const String authChoiceHint =
      'Google is the fastest way in. You can always use email instead.';
  static const String orContinueWith = 'or continue with';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String signUp = 'Sign Up';
  static const String forgotPassword = 'Forgot password?';
  static const String forgotPasswordTitle = 'Reset Password';
  static const String forgotPasswordSubtitle =
      'Enter your email and we\'ll send you a link to reset your password.';
  static const String sendResetLink = 'Send Reset Link';
  static const String resetPasswordEmailSent =
      'If an account exists for that email, we sent a reset link.';
  static const String chooseNewPassword = 'Choose a new password';
  static const String resetPasswordSubtitle =
      'Enter a new password for your account.';
  static const String updatePassword = 'Update Password';
  static const String passwordUpdatedSuccessfully =
      'Your password has been updated.';
  static const String resetPasswordFailedPleaseTryAgain =
      'We couldn\'t update your password right now. Please try again.';

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
  static const String invalidEmailOrPassword =
      'That email or password doesn\'t look right. Try again.';
  static const String pleaseConfirmYourEmailBeforeLoggingIn =
      'Check your inbox and confirm your email before signing in.';
  static const String userNotFoundPleaseSignUpFirst =
      'We couldn\'t find an account with that email. Create one to get started.';
  static const String loginFailedPleaseTryAgain =
      'We couldn\'t sign you in right now. Please try again.';

  // Signup Errors
  static const String thisEmailIsAlreadyRegisteredPleaseSignInInstead =
      'An account already exists for that email. Try signing in instead.';
  static const String pleaseEnterAValidEmailAddress =
      'Enter a valid email address to continue.';
  static const String confirmationEmailCouldNotBeSent =
      'We couldn\'t send the confirmation email right now. Please try again in a bit.';
  static const String signupFailedPleaseTryAgain =
      'We couldn\'t create your account right now. Please try again.';

  // Network Errors
  static const String networkErrorPleaseCheckYourConnection =
      'Check your connection and try again.';
  static const String appleSignInCanceled = 'Apple sign-in was canceled.';
  static const String appleSignInNotConfigured =
      'Apple sign-in isn\'t fully configured yet.';
  static const String appleSignInNotSupported =
      'Apple sign-in isn\'t supported on this device.';
  static const String appleSignInConfigurationIssue =
      'Apple sign-in isn\'t available right now. Please try again later.';
  static const String appleSignInFailedPleaseTryAgain =
      'We couldn\'t sign you in with Apple. Please try again.';
  static const String googleSignInCanceled = 'Google sign-in was canceled.';
  static const String googleSignInInterrupted =
      'Google sign-in was interrupted. Try again.';
  static const String googleSignInNotConfigured =
      'Google sign-in isn\'t available right now.';
  static const String googleSignInNotSupported =
      'Google sign-in isn\'t supported on this device.';
  static const String googleSignInConfigurationIssue =
      'Google sign-in isn\'t available right now. Please try again later.';
  static const String googleSignInUiUnavailable =
      'We couldn\'t open Google sign-in. Try again.';
  static const String googleSignInUserMismatch =
      'Your Google session changed. Try signing in again.';
  static const String googleSignInFailedPleaseTryAgain =
      'We couldn\'t sign you in with Google. Please try again.';

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
  static const String blockedUsers = 'Blocked users';
  static const String termsAndConditions = 'Terms and conditions';
  static const String privacyPolicy = 'Privacy policy';
  static const String deleteAccount = 'Delete account';
  static const String deleteAccountDialogTitle = 'Delete account?';
  static const String deleteAccountDialogMessage =
      'This permanently deletes your ratings, followers, following, uploaded videos, and profile data. This can\'t be undone.';
  static const String deleteAccountFailed = 'Delete account failed';
  static const String logOut = 'Log out';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String recordVideo = 'Record Video';

  // Camera Permission Strings
  static const String cameraAccessRequired = 'Camera Access Required';
  static const String cameraPermissionBody =
      'To record videos, we need access to your camera. Please enable camera permissions in app settings.';
  static const String openSettings = 'Open Settings';
}
