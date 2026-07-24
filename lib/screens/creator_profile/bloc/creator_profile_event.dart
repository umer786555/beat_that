part of 'creator_profile_bloc.dart';

sealed class CreatorProfileEvent extends Equatable {
  const CreatorProfileEvent();

  @override
  List<Object> get props => [];
}

final class LoadCreatorProfileEvent extends CreatorProfileEvent {
  const LoadCreatorProfileEvent();
}

final class ToggleFollowStatusEvent extends CreatorProfileEvent {
  const ToggleFollowStatusEvent();
}

final class LoadMoreCreatorProfileVideosEvent extends CreatorProfileEvent {
  const LoadMoreCreatorProfileVideosEvent();
}
