part of 'settings_bloc.dart';

enum SettingsStatus {
  idle,
  loggingOut,
  loggedOut,
  resettingOnboarding,
  onboardingReset,
  deletingAccount,
  deletedAccount,
  failure,
}

final class SettingsState extends Equatable {
  const SettingsState({this.status = SettingsStatus.idle, this.errorMessage});

  final SettingsStatus status;
  final String? errorMessage;

  bool get isLoggingOut => status == SettingsStatus.loggingOut;
  bool get isResettingOnboarding =>
      status == SettingsStatus.resettingOnboarding;
  bool get isDeletingAccount => status == SettingsStatus.deletingAccount;
  bool get isBusy => isLoggingOut || isDeletingAccount || isResettingOnboarding;

  SettingsState copyWith({
    SettingsStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
