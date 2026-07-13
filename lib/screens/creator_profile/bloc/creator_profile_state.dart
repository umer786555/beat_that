part of 'creator_profile_bloc.dart';

sealed class CreatorProfileState extends Equatable {
  const CreatorProfileState();

  @override
  List<Object> get props => [];
}

final class CreatorProfileInitial extends CreatorProfileState {
  const CreatorProfileInitial();
}

final class CreatorProfileLoading extends CreatorProfileState {
  const CreatorProfileLoading();
}

final class CreatorProfileLoaded extends CreatorProfileState {
  const CreatorProfileLoaded({required this.profile, required this.videos});

  final UserPersonalProfile profile;
  final List<VideoThumbnailModel> videos;

  @override
  List<Object> get props => [profile.username, profile.profileUrl ?? '', videos];
}

final class CreatorProfileError extends CreatorProfileState {
  const CreatorProfileError({required this.message});

  final String message;

  @override
  List<Object> get props => [message];
}