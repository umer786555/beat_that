part of 'profile_bloc.dart';

sealed class ProfilePresentationEvent {}

final class ProfileDeleteVideoSuccessEvent extends ProfilePresentationEvent {
  final String message;

  ProfileDeleteVideoSuccessEvent({required this.message});
}

final class ProfileDeleteVideoErrorEvent extends ProfilePresentationEvent {
  final String message;

  ProfileDeleteVideoErrorEvent({required this.message});
}
