part of 'profile_bloc.dart';

sealed class ProfilePresentationEvent {
  final String message;

  const ProfilePresentationEvent({required this.message});
}

final class ProfileSuccessMessageEvent extends ProfilePresentationEvent {
  const ProfileSuccessMessageEvent({required super.message});
}

final class ProfileErrorMessageEvent extends ProfilePresentationEvent {
  const ProfileErrorMessageEvent({required super.message});
}
