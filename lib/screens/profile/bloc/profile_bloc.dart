import 'dart:io';

import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

part 'profile_event.dart';
part 'profile_presentation_event.dart';
part 'profile_state.dart';

/// Handlers run concurrently, so every handler re-reads [state] after an
/// `await` (via [_updateLoaded]) instead of reusing a snapshot taken before it.
/// Otherwise one handler would overwrite changes made by another.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState>
    with BlocPresentationMixin<ProfileState, ProfilePresentationEvent> {
  ProfileBloc({
    SupabaseService? supabaseService,
    PreferencesService? preferencesService,
    PermissionService? permissionService,
    VideoPickerService? videoPickerService,
  }) : _supabaseService = supabaseService ?? locator<SupabaseService>(),
       _preferencesService =
           preferencesService ?? locator<PreferencesService>(),
       _permissionService = permissionService ?? locator<PermissionService>(),
       _videoPickerService =
           videoPickerService ?? locator<VideoPickerService>(),
       super(const ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<AddProfileImageEvent>(_onAddProfileImage);
    on<DeleteVideoEvent>(_onDeleteVideo);
    on<RefreshVideosEvent>(_onRefreshVideos);
    on<VideoApprovalUpdatedEvent>(_onVideoApprovalUpdated);
  }

  final SupabaseService _supabaseService;
  final PreferencesService _preferencesService;
  final PermissionService _permissionService;
  final VideoPickerService _videoPickerService;

  /// Cached so the profile image upload can use the username.
  UserPersonalProfile? _userProfile;

  /// Guards the whole photo flow, including the permission prompt and picker,
  /// which run before [ProfileLoaded.isUploadingProfileImage] is set.
  bool _isUpdatingProfileImage = false;

  /// Listens for approval changes while any video is pending review.
  RealtimeChannel? _approvalChannel;

  /// Loads the profile and videos.
  ///
  /// The first load shows [ProfileLoading]. Later loads (pull-to-refresh) keep
  /// the current profile on screen, flag [ProfileLoaded.isRefreshing], and
  /// report failures as a snackbar instead of replacing the screen.
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is ProfileLoaded) {
      _updateLoaded(emit, (loaded) => loaded.copyWith(isRefreshing: true));
    } else {
      emit(const ProfileLoading());
    }

    try {
      final myVideos = await _supabaseService.getMyVideo();
      final userProfile = await _preferencesService.fetchUserProfile();
      _userProfile = userProfile;

      final latestState = state;
      if (latestState is ProfileLoaded) {
        emit(
          latestState.copyWith(
            myVideos: myVideos,
            username: userProfile?.username,
            profileUrl: userProfile?.profileUrl,
            isRefreshing: false,
          ),
        );
      } else {
        emit(
          ProfileLoaded(
            myVideos: myVideos,
            username: userProfile?.username,
            profileUrl: userProfile?.profileUrl,
          ),
        );
      }

      await _syncApprovalSubscription(myVideos);
    } catch (e) {
      debugPrint('[PROFILE] Failed to load profile: $e');

      // Checks the latest state: a concurrent load may have succeeded meanwhile.
      if (state is ProfileLoaded) {
        _updateLoaded(emit, (loaded) => loaded.copyWith(isRefreshing: false));
        emitPresentation(
          const ProfileErrorMessageEvent(
            message: AppStrings.failedToRefreshProfile,
          ),
        );
      } else {
        emit(const ProfileError(message: AppStrings.failedToLoadProfile));
      }
    }
  }

  /// Asks for photo access, lets the user pick a photo, and uploads it.
  ///
  /// The profile stays on screen during the upload;
  /// [ProfileLoaded.isUploadingProfileImage] drives the in-place indicator.
  Future<void> _onAddProfileImage(
    AddProfileImageEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoaded || _isUpdatingProfileImage) {
      return;
    }

    _isUpdatingProfileImage = true;
    try {
      final hasAccess = await _permissionService.requestPhotosAccess();
      if (!hasAccess) {
        emitPresentation(
          const ProfileErrorMessageEvent(
            message: AppStrings.photoAccessRequired,
          ),
        );
        return;
      }

      final selectedPhoto = await _videoPickerService.pickGalleryPhoto();
      if (selectedPhoto == null) {
        return;
      }

      _updateLoaded(
        emit,
        (loaded) => loaded.copyWith(isUploadingProfileImage: true),
      );

      final uploadResult = await _supabaseService.uploadAndSaveProfileImage(
        File(selectedPhoto.path),
        _userProfile?.username ?? '',
      );
      if (uploadResult['success'] != true) {
        throw Exception(uploadResult['error']);
      }

      final updatedProfile = await _supabaseService.fetchUserPersonalProfile();
      if (updatedProfile != null) {
        _userProfile = updatedProfile;
        await _preferencesService.saveUserProfile(updatedProfile);
      }

      _updateLoaded(
        emit,
        (loaded) => loaded.copyWith(
          profileUrl: updatedProfile?.profileUrl,
          isUploadingProfileImage: false,
        ),
      );
    } catch (e) {
      debugPrint('[PROFILE] Failed to update profile image: $e');
      _updateLoaded(
        emit,
        (loaded) => loaded.copyWith(isUploadingProfileImage: false),
      );
      emitPresentation(
        const ProfileErrorMessageEvent(
          message: AppStrings.failedToUpdateProfilePhoto,
        ),
      );
    } finally {
      _isUpdatingProfileImage = false;
    }
  }

  /// Deletes a video through the Supabase Edge Function.
  ///
  /// Only one delete runs at a time; requests made while one is in flight are
  /// ignored.
  Future<void> _onDeleteVideo(
    DeleteVideoEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isDeletingVideo) {
      return;
    }

    emit(currentState.copyWith(nextDeletingVideoId: event.videoId));

    try {
      final deleteResult = await _supabaseService.deleteMyVideoViaEdgeFunction(
        videoId: event.videoId,
      );
      if (deleteResult['success'] != true) {
        throw Exception(deleteResult['error']);
      }

      _updateLoaded(
        emit,
        (loaded) => loaded.copyWith(
          myVideos: loaded.myVideos
              .where((video) => video.id != event.videoId)
              .toList(),
          nextDeletingVideoId: null,
        ),
      );
      emitPresentation(
        const ProfileSuccessMessageEvent(message: AppStrings.videoDeleted),
      );

      final latestState = state;
      if (latestState is ProfileLoaded) {
        await _syncApprovalSubscription(latestState.myVideos);
      }
    } catch (e) {
      debugPrint('[PROFILE] Failed to delete video ${event.videoId}: $e');
      _updateLoaded(
        emit,
        (loaded) => loaded.copyWith(nextDeletingVideoId: null),
      );
      emitPresentation(
        const ProfileErrorMessageEvent(message: AppStrings.failedToDeleteVideo),
      );
    }
  }

  /// Re-fetches only the videos, e.g. after an upload.
  ///
  /// Falls back to a full load when no profile is on screen yet.
  Future<void> _onRefreshVideos(
    RefreshVideosEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoaded) {
      add(const LoadProfileEvent());
      return;
    }

    try {
      final myVideos = await _supabaseService.getMyVideo();
      _updateLoaded(emit, (loaded) => loaded.copyWith(myVideos: myVideos));
      await _syncApprovalSubscription(myVideos);
    } catch (e) {
      debugPrint('[PROFILE] Failed to refresh videos: $e');
      emitPresentation(
        const ProfileErrorMessageEvent(
          message: AppStrings.failedToRefreshVideos,
        ),
      );
    }
  }

  /// Applies a realtime approval change to the matching video.
  ///
  /// Updates for videos not in the list are ignored: the list is refreshed
  /// after every upload, and the next load picks up anything missed.
  Future<void> _onVideoApprovalUpdated(
    VideoApprovalUpdatedEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) {
      return;
    }

    final videoIndex = currentState.myVideos.indexWhere(
      (video) => video.id == event.videoId,
    );
    if (videoIndex == -1) {
      return;
    }

    final updatedVideos = List<MyVideo>.of(currentState.myVideos);
    updatedVideos[videoIndex] = updatedVideos[videoIndex].copyWith(
      approved: event.approvalStatus,
    );

    emit(currentState.copyWith(myVideos: updatedVideos));
    await _syncApprovalSubscription(updatedVideos);
  }

  /// Emits [update] applied to the latest state, if a profile is on screen.
  void _updateLoaded(
    Emitter<ProfileState> emit,
    ProfileLoaded Function(ProfileLoaded loaded) update,
  ) {
    final latestState = state;
    if (latestState is ProfileLoaded) {
      emit(update(latestState));
    }
  }

  /// Keeps the realtime channel open only while a video awaits approval.
  Future<void> _syncApprovalSubscription(List<MyVideo> videos) async {
    final hasPendingApproval = videos.any((video) => video.approved == null);

    if (!hasPendingApproval) {
      await _unsubscribeFromApprovalChanges();
      return;
    }

    if (_approvalChannel != null || isClosed) {
      return;
    }

    try {
      _approvalChannel = _supabaseService.subscribeToVideoApprovalChanges(
        onApprovalChanged: (videoId, approvalStatus) {
          if (isClosed) {
            return;
          }
          add(
            VideoApprovalUpdatedEvent(
              videoId: videoId,
              approvalStatus: approvalStatus,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('[PROFILE] Failed to subscribe to approval changes: $e');
    }
  }

  Future<void> _unsubscribeFromApprovalChanges() async {
    final channel = _approvalChannel;
    if (channel == null) {
      return;
    }

    // Cleared before awaiting so a concurrent sync can open a fresh channel.
    _approvalChannel = null;
    try {
      await channel.unsubscribe();
    } catch (e) {
      debugPrint('[PROFILE] Failed to unsubscribe from approval changes: $e');
    }
  }

  @override
  Future<void> close() async {
    // Closing first sets isClosed, so a handler still in flight can't open a
    // new channel while the old one is unsubscribing.
    await super.close();
    await _unsubscribeFromApprovalChanges();
  }
}
