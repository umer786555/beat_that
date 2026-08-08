import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'creator_profile_event.dart';
part 'creator_profile_presentation_event.dart';
part 'creator_profile_state.dart';

class CreatorProfileBloc extends Bloc<CreatorProfileEvent, CreatorProfileState>
    with
        BlocPresentationMixin<
          CreatorProfileState,
          CreatorProfilePresentationEvent
        > {
  static const int _pageSize = 20;

  CreatorProfileBloc({required this.userId})
    : _supabaseService = locator<SupabaseService>(),
      super(const CreatorProfileInitial()) {
    on<LoadCreatorProfileEvent>(_onLoadCreatorProfile);
    on<LoadMoreCreatorProfileVideosEvent>(_onLoadMoreCreatorProfileVideos);
    on<ToggleFollowStatusEvent>(_onToggleFollowStatus);
  }

  final String userId;
  final SupabaseService _supabaseService;

  Future<void> _onLoadCreatorProfile(
    LoadCreatorProfileEvent event,
    Emitter<CreatorProfileState> emit,
  ) async {
    emit(const CreatorProfileLoading());

    try {
      final result = await _supabaseService.fetchUserProfileWithUploadedVideos(
        userId,
        _pageSize,
        0,
      );

      if (result['success'] != true) {
        emit(
          CreatorProfileError(
            message:
                result['error'] as String? ?? 'Failed to load creator profile.',
          ),
        );
        return;
      }

      final profile = result['profile'] as UserPersonalProfile;
      final videos = result['videos'] as List<MyVideo>;
      final totalVideoCount =
          result['totalVideoCount'] as int? ?? videos.length;
      final hasMoreVideos = result['hasMoreVideos'] == true;
      final isOwnProfile = _supabaseService.getCurrentUserId() == userId;
      final isFollowing = isOwnProfile
          ? false
          : (await _supabaseService.checkIsFollowing(
                  userId: userId,
                ))['isFollowing'] ==
                true;

      emit(
        CreatorProfileLoaded(
          profile: profile,
          videos: videos,
          totalVideoCount: totalVideoCount,
          isFollowing: isFollowing,
          isOwnProfile: isOwnProfile,
          hasMoreVideos: hasMoreVideos,
        ),
      );
    } catch (e) {
      emit(CreatorProfileError(message: 'Failed to load creator profile: $e'));
    }
  }

  Future<void> _onLoadMoreCreatorProfileVideos(
    LoadMoreCreatorProfileVideosEvent event,
    Emitter<CreatorProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CreatorProfileLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMoreVideos ||
        currentState.videos.length >= currentState.totalVideoCount) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final result = await _supabaseService.fetchUserProfileWithUploadedVideos(
        userId,
        _pageSize,
        currentState.videos.length,
      );

      if (result['success'] != true) {
        emit(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final newVideos = result['videos'] as List<MyVideo>;
      final hasMoreVideos = result['hasMoreVideos'] == true;
      if (newVideos.isEmpty) {
        emit(currentState.copyWith(hasMoreVideos: false, isLoadingMore: false));
        return;
      }

      emit(
        currentState.copyWith(
          videos: [...currentState.videos, ...newVideos],
          hasMoreVideos: hasMoreVideos,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onToggleFollowStatus(
    ToggleFollowStatusEvent event,
    Emitter<CreatorProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CreatorProfileLoaded ||
        currentState.isOwnProfile ||
        currentState.isUpdatingFollow) {
      return;
    }

    emit(currentState.copyWith(isUpdatingFollow: true));

    try {
      final result = currentState.isFollowing
          ? await _supabaseService.unfollowUser(userIdToUnfollow: userId)
          : await _supabaseService.followUser(userIdToFollow: userId);

      if (result['success'] != true) {
        emit(currentState.copyWith(isUpdatingFollow: false));
        emitPresentation(
          CreatorProfileFollowStatusErrorEvent(
            result['error'] as String? ?? 'Unable to update follow status.',
          ),
        );
        return;
      }

      emit(
        currentState.copyWith(
          isFollowing: !currentState.isFollowing,
          isUpdatingFollow: false,
        ),
      );
      emitPresentation(CreatorProfileFollowStatusUpdatedEvent());
    } catch (e) {
      emit(currentState.copyWith(isUpdatingFollow: false));
      emitPresentation(
        CreatorProfileFollowStatusErrorEvent(
          'Unable to update follow status: $e',
        ),
      );
    }
  }
}
