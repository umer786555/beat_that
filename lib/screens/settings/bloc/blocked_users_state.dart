part of 'blocked_users_cubit.dart';

class BlockedUsersState extends Equatable {
  const BlockedUsersState({
    this.users = const <UserBlock>[],
    this.unblockingUserIds = const <String>[],
    this.isLoading = true,
    this.screenErrorMessage,
    this.feedbackMessage,
    this.isFeedbackError = false,
  });

  final List<UserBlock> users;
  final List<String> unblockingUserIds;
  final bool isLoading;
  final String? screenErrorMessage;
  final String? feedbackMessage;
  final bool isFeedbackError;

  BlockedUsersState copyWith({
    List<UserBlock>? users,
    List<String>? unblockingUserIds,
    bool? isLoading,
    String? screenErrorMessage,
    String? feedbackMessage,
    bool? isFeedbackError,
    bool clearScreenErrorMessage = false,
    bool clearFeedbackMessage = false,
  }) {
    return BlockedUsersState(
      users: users ?? this.users,
      unblockingUserIds: unblockingUserIds ?? this.unblockingUserIds,
      isLoading: isLoading ?? this.isLoading,
      screenErrorMessage: clearScreenErrorMessage
          ? null
          : (screenErrorMessage ?? this.screenErrorMessage),
      feedbackMessage: clearFeedbackMessage
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      isFeedbackError: isFeedbackError ?? this.isFeedbackError,
    );
  }

  @override
  List<Object?> get props => [
    users,
    unblockingUserIds,
    isLoading,
    screenErrorMessage,
    feedbackMessage,
    isFeedbackError,
  ];
}