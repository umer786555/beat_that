part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

final class LogoutRequested extends SettingsEvent {
  const LogoutRequested();
}

final class DeleteAccountRequested extends SettingsEvent {
  const DeleteAccountRequested();
}
