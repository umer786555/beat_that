part of 'creator_profile_bloc.dart';

sealed class CreatorProfileEvent extends Equatable {
  const CreatorProfileEvent();

  @override
  List<Object> get props => [];
}

final class LoadCreatorProfileEvent extends CreatorProfileEvent {
  const LoadCreatorProfileEvent();
}