import 'package:beat_that/models/user_profile_summary.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'blocked_users_state.dart';

class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  BlockedUsersCubit()
    : _supabaseService = locator<SupabaseService>(),
      super(const BlockedUsersState());

  final SupabaseService _supabaseService;

  Future<void> loadBlockedUsers({bool showLoadingState = true}) async {
    if (showLoadingState) {
      emit(
        state.copyWith(
          isLoading: true,
          clearScreenErrorMessage: true,
          clearFeedbackMessage: true,
        ),
      );
    }

    try {
      final blockedUsers = await _supabaseService.getBlockedUsers();
      emit(
        state.copyWith(
          users: blockedUsers,
          isLoading: false,
          clearScreenErrorMessage: true,
          clearFeedbackMessage: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          screenErrorMessage: 'Failed to load blocked users',
        ),
      );
    }
  }

  Future<void> unblockUser(UserProfileSummary user) async {
    if (state.unblockingUserIds.contains(user.id)) {
      return;
    }

    emit(
      state.copyWith(
        unblockingUserIds: <String>[...state.unblockingUserIds, user.id],
        clearFeedbackMessage: true,
      ),
    );

    final result = await _supabaseService.unblockUser(
      userIdToUnblock: user.id,
    );

    final updatedUnblockingIds = state.unblockingUserIds
        .where((id) => id != user.id)
        .toList(growable: false);

    if (result['success'] == true) {
      emit(
        state.copyWith(
          users: state.users
              .where((blockedUser) => blockedUser.id != user.id)
              .toList(growable: false),
          unblockingUserIds: updatedUnblockingIds,
          feedbackMessage: '${user.username} unblocked',
          isFeedbackError: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        unblockingUserIds: updatedUnblockingIds,
        feedbackMessage:
            result['error']?.toString() ?? 'Failed to unblock user',
        isFeedbackError: true,
      ),
    );
  }

  void clearFeedback() {
    if (state.feedbackMessage == null) {
      return;
    }

    emit(state.copyWith(clearFeedbackMessage: true));
  }
}