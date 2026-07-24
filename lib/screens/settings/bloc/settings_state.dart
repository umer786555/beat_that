part of 'settings_bloc.dart';

enum SettingsStatus {
  idle,
  loggingOut,
  loggedOut,
  deletingAccount,
  deletedAccount,
  failure,
}

final class SettingsState extends Equatable {
  const SettingsState({this.status = SettingsStatus.idle, this.errorMessage});

  final SettingsStatus status;
  final String? errorMessage;

  bool get isLoggingOut => status == SettingsStatus.loggingOut;
  bool get isDeletingAccount => status == SettingsStatus.deletingAccount;
  bool get isBusy => isLoggingOut || isDeletingAccount;

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
