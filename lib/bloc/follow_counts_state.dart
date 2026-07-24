part of 'follow_counts_cubit.dart';

class FollowCountsState extends Equatable {
  const FollowCountsState({
    this.followers = 0,
    this.following = 0,
    this.isLoading = false,
  });

  final int followers;
  final int following;
  final bool isLoading;

  FollowCountsState copyWith({
    int? followers,
    int? following,
    bool? isLoading,
  }) {
    return FollowCountsState(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object> get props => [followers, following, isLoading];
}
