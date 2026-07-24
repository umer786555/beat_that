import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'follow_counts_state.dart';

/// Shared app-level state for the signed-in user's follow counts.
///
/// This is intentionally separate from `ProfileBloc` so screens like
/// `CreatorProfileScreen` can trigger count refreshes without depending on the
/// current profile screen's widget tree or bloc scope.
class FollowCountsCubit extends Cubit<FollowCountsState> {
  FollowCountsCubit()
    : _supabaseService = locator<SupabaseService>(),
      super(const FollowCountsState());

  final SupabaseService _supabaseService;

  /// Refreshes the current user's follower/following counts from Supabase.
  ///
  /// The cubit is provided above the router, making it safe to use from any
  /// route that can affect follow state.
  Future<void> refresh() async {
    final userId = _supabaseService.getCurrentUserId();
    if (userId == null) {
      emit(const FollowCountsState());
      return;
    }

    emit(state.copyWith(isLoading: true));

    try {
      final followerCountResult = await _supabaseService.getFollowerCount();
      final followingCountResult = await _supabaseService.getFollowingCount();

      emit(
        FollowCountsState(
          followers: followerCountResult['success'] == true
              ? followerCountResult['count'] as int
              : state.followers,
          following: followingCountResult['success'] == true
              ? followingCountResult['count'] as int
              : state.following,
          isLoading: false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void reset() {
    emit(const FollowCountsState());
  }
}
