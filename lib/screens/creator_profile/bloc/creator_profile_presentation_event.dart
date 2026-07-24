part of 'creator_profile_bloc.dart';

sealed class CreatorProfilePresentationEvent {}

final class CreatorProfileFollowStatusUpdatedEvent
    extends CreatorProfilePresentationEvent {}

final class CreatorProfileFollowStatusErrorEvent
        extends CreatorProfilePresentationEvent {
    CreatorProfileFollowStatusErrorEvent(this.message);

    final String message;
}