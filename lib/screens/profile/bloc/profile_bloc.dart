import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:beat_that/constants/app_enums.dart';

import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
part 'profile_event.dart';
part 'profile_presentation_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState>
    with BlocPresentationMixin<ProfileState, ProfilePresentationEvent> {
  final permissionService = locator<PermissionService>();
  final supabaseService = locator<SupabaseService>();
  final authService = locator<AuthService>();
  final preferencesService = locator<PreferencesService>();
  final videoPickerService = locator<VideoPickerService>();

  // Cache user profile at block level for access across all handlers
  late UserPersonalProfile? userProfile;

  // Realtime channel for listening to video approval changes
  // Stored at bloc level to enable proper cleanup on close()
  RealtimeChannel? _approvalChannel;

  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<AddProfileImageEvent>(_onAddProfileImage);
    on<DeleteVideoEvent>(_onDeleteVideo);
    on<RefreshVideosEvent>(_onRefreshVideos);
    on<VideoApprovalUpdatedEvent>(_onVideoApprovalUpdated);
  }

  /// Load profile data and fetch thumbnail URLs
  ///
  /// This event performs three sequential operations:
  /// 1. Check camera and gallery permssions
  /// 2. Fetch all thumbnail URLs for the current user's videos
  /// 3. Fetch the username from preferences
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ProfileLoading());

      // Step 1: Check if camera and gallery permissions are enabled
      final cameraPermissionEnabled = await permissionService
          .checkCameraPermissionOnLoad();
      final galleryPermissionEnabled = await permissionService
          .checkPhotosPermissionOnLoad();

      // Step 2: Fetch all thumbnail URLs for the current user's videos from Supabase 
      final myVideos = await supabaseService.getMyVideo();

      // Step 3: Fetch the username from preferences and cache at block level
      userProfile = await preferencesService.fetchUserProfile();

      // Initialize with permissions, thumbnails, and cached profile data.
      emit(
        ProfileLoaded(
          cameraPermissionEnabled: cameraPermissionEnabled,
          galleryPermissionEnabled: galleryPermissionEnabled,
          myVideo: myVideos,
          username: userProfile?.username,
          profileUrl: userProfile?.profileUrl,
        ),
      );

      // ==================== Setup Realtime Listener ====================
      // Only subscribe to approval changes if any video has a null approved status
      final hasNullApproval = myVideos.any((video) => video.approved == null);

      if (hasNullApproval) {
        print('[PROFILE] Videos with null approval detected - subscribing to realtime updates');
        _subscribeToApprovalChanges();
      } else {
        print('[PROFILE] All videos have approval status - realtime listener not needed');
      }
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.failedToLoadProfile}: $e'));
    }
  }

  /// Subscribe to real-time approval status changes
  ///
  /// Sets up a Supabase realtime channel to listen for UPDATE events on the
  /// my_videos table. When the approved field changes, emits VideoApprovalUpdatedEvent.
  void _subscribeToApprovalChanges() {
    try {
      _approvalChannel = supabaseService.subscribeToVideoApprovalChanges(
        onApprovalChanged: (videoId, approvalStatus) {
          // Emit event to handle the approval status change
          add(VideoApprovalUpdatedEvent(
            videoId: videoId,
            approvalStatus: approvalStatus,
          ));
        },
      );
      print('[PROFILE] Successfully subscribed to approval changes');
    } catch (e) {
      print('[ERROR] Failed to subscribe to approval changes: $e');
    }
  }

  /// Handle adding a profile image
  /// Checks photos permission, requests if needed, opens gallery picker, and uploads to Supabase
  Future<void> _onAddProfileImage(
    AddProfileImageEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Check current photos permission status
      final currentStatus = await Permission.photos.status;

      bool hasPermission = currentStatus.isGranted;

      // If permission is not granted, request it
      if (!hasPermission) {
        final permissionGranted =
            await PermissionService.requestPhotosPermission();

        if (!permissionGranted) {
          // Permission denied or restricted - cannot proceed
          return;
        }
        hasPermission = true;
      }

      // If we have permission, open the gallery picker
      if (hasPermission) {
        final selectedPhoto = await videoPickerService.pickGalleryPhoto();

        if (selectedPhoto != null) {
          print('Profile photo selected: ${selectedPhoto.path}');

          // Save current state before emitting loading
          final previousState = state;

          // ==================== Upload to Supabase ====================
          emit(ProfileLoading());

          // Convert XFile to File
          final photoFile = _xfileToFile(selectedPhoto);

          // Use cached username from block level
          final username = userProfile?.username ?? '';

          final uploadResult = await supabaseService.uploadAndSaveProfileImage(
            photoFile,
            username,
          );

          if (uploadResult['success']) {
            print('✓ Profile image uploaded successfully!');

            // Fetch updated profile to cache locally
            final updatedProfile = await supabaseService
                .fetchUserPersonalProfile();

            if (updatedProfile != null) {
              // Update class-level cache with new profile
              userProfile = updatedProfile;

              // Save updated profile to preferences
              await preferencesService.saveUserProfile(updatedProfile);

              // Emit success - restore to ProfileLoaded state with updated profileUrl
              if (previousState is ProfileLoaded) {
                emit(
                  previousState.copyWith(profileUrl: updatedProfile.profileUrl),
                );
              }
            }
          } else {
            emit(
              ProfileError(
                message:
                    'Failed to upload profile image: ${uploadResult['error']}',
              ),
            );
          }
        }
      }
    } catch (e) {
      emit(ProfileError(message: 'Failed to add profile image: $e'));
    }
  }

  /// Convert XFile to File
  /// XFile is returned by image_picker, but Supabase service expects File
  File _xfileToFile(dynamic xfile) {
    return File(xfile.path);
  }

  /// Handle deleting a video
  /// Deletes a video through the Supabase Edge Function.
  Future<void> _onDeleteVideo(
    DeleteVideoEvent event,
    Emitter<ProfileState> emit,
  ) async {
    print('Attempting to delete video with ID: ${event.videoId}');

    try {
      // Save current state before emitting loading
      final previousState = state;
      emit(ProfileLoading());

      // Call Supabase service to delete the video
      final deleteResult = await supabaseService.deleteMyVideoViaEdgeFunction(
        videoId: event.videoId,
      );

      if (deleteResult['success']) {
        print('✓ Video deleted successfully!');

        // Fetch updated thumbnails after deletion
        final updatedThumbnails = await supabaseService.getMyVideo();

        // Emit success with updated thumbnails
        if (previousState is ProfileLoaded) {
          emit(previousState.copyWith(thumbnails: updatedThumbnails));
        } else {
          // Fallback: just trigger full profile load
          add(LoadProfileEvent());
        }
      } else {
        emit(
          ProfileError(
            message: 'Failed to delete video: ${deleteResult['error']}',
          ),
        );
      }
    } catch (e) {
      emit(ProfileError(message: 'Failed to delete video: $e'));
    }
  }

  /// Refresh videos list by fetching updated thumbnails
  /// Lightweight refresh that only updates the thumbnails list without reloading permissions
  /// Used when a video is uploaded or modified
  Future<void> _onRefreshVideos(
    RefreshVideosEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Save current state before emitting loading
      final previousState = state;
      emit(ProfileLoading());

      // Fetch updated thumbnails
      final updatedThumbnails = await supabaseService.getMyVideo();

      // Emit success with updated thumbnails
      if (previousState is ProfileLoaded) {
        emit(previousState.copyWith(thumbnails: updatedThumbnails));
      } else {
        // Fallback: just trigger full profile load
        add(LoadProfileEvent());
      }
    } catch (e) {
      emit(ProfileError(message: 'Failed to refresh videos: $e'));
    }
  }

  /// Handle real-time video approval status updates
  ///
  /// When a video's approval status changes in Supabase, this handler:
  /// 1. Finds the video in the current state by ID
  /// 2. Updates the video's approved field with the new value
  /// 3. Emits a new ProfileLoaded state with the updated videos
  ///
  /// This maintains the reactive nature of the bloc while only updating the
  /// specific video that changed, rather than refreshing all videos.
  Future<void> _onVideoApprovalUpdated(
    VideoApprovalUpdatedEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;

      // Only process if we're in ProfileLoaded state
      if (currentState is! ProfileLoaded) {
        print('[PROFILE] Ignoring approval update - not in ProfileLoaded state');
        return;
      }

      // Find the video that was updated
      final videoIndex = currentState.myVideo
          .indexWhere((video) => video.id == event.videoId);

      if (videoIndex == -1) {
        print(
          '[PROFILE] Video not found for approval update: ${event.videoId}',
        );
        return;
      }

      // Create updated video with new approval status
      final updatedVideo = currentState.myVideo[videoIndex].copyWith(
        approved: event.approvalStatus,
      );

      // Create new videos list with updated video
      final updatedVideos = List<MyVideo>.from(currentState.myVideo);
      updatedVideos[videoIndex] = updatedVideo;

      print(
        '[PROFILE] Updated video approval: ${event.videoId} -> ${event.approvalStatus}',
      );

      // Emit updated state with modified videos list
      emit(currentState.copyWith(thumbnails: updatedVideos));
    } catch (e) {
      print('[ERROR] Failed to handle approval update: $e');
    }
  }

  /// Clean up resources when the bloc is closed
  ///
  /// Unsubscribes from the realtime channel to prevent memory leaks
  /// and stop receiving approval change updates.
  @override
  Future<void> close() async {
    if (_approvalChannel != null) {
      try {
        print('[PROFILE] Unsubscribing from approval changes');
        await _approvalChannel!.unsubscribe();
        _approvalChannel = null;
      } catch (e) {
        print('[ERROR] Failed to unsubscribe from approval changes: $e');
      }
    }
    return super.close();
  }

  /// Handle logout
  // Future<void> _onLogout(LogoutEvent event, Emitter<ProfileState> emit) async {
  //   try {
  //     emit(ProfileLoading());
  //     await authService.logout();
  //   } catch (e) {
  //     emit(ProfileError(message: '${AppStrings.logoutFailed}: $e'));
  //   }
  // }

  /// Handle camera permission request
  // Future<void> _onRequestCameraPermission(
  //   RequestCameraPermissionEvent event,
  //   Emitter<ProfileState> emit,
  // ) async {
  //   try {
  //     // Check current permission status
  //     final status = await Permission.camera.status;

  //     if (status.isGranted) {
  //       // Permission already granted - update ProfileLoaded state
  //       emit((state as ProfileLoaded).copyWith(cameraPermissionEnabled: true));
  //       return;
  //     }

  //     // Request permission
  //     final permissionGranted =
  //         await PermissionService.requestCameraPermission();

  //     if (permissionGranted) {
  //       // Permission granted after request - update ProfileLoaded state
  //       emit((state as ProfileLoaded).copyWith(cameraPermissionEnabled: true));
  //     } else {
  //       // Permission denied - show permission denied state
  //       final finalStatus = await Permission.camera.status;
  //       emit(
  //         CameraPermissionDenied(
  //           isPermanentlyDenied: finalStatus.isPermanentlyDenied,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     emit(ProfileError(message: 'Failed to request camera permission: $e'));
  //   }
  // }

  /// Handle gallery permission request
  // Future<void> _onRequestGalleryPermission(
  //   RequestGalleryPermissionEvent event,
  //   Emitter<ProfileState> emit,
  // ) async {
  //   try {
  //     // Check current permission status
  //     final status = await Permission.photos.status;

  //     if (status.isGranted) {
  //       // Permission already granted - update ProfileLoaded state
  //       emit((state as ProfileLoaded).copyWith(galleryPermissionEnabled: true));
  //       return;
  //     }

  //     // Request permission
  //     final permissionGranted =
  //         await PermissionService.requestPhotosPermission();

  //     if (permissionGranted) {
  //       // Permission granted after request - update ProfileLoaded state
  //       emit((state as ProfileLoaded).copyWith(galleryPermissionEnabled: true));
  //     } else {
  //       // Permission denied - show permission denied state
  //       emit(
  //         (state as ProfileLoaded).copyWith(galleryPermissionEnabled: false),
  //       );
  //     }
  //   } catch (e) {
  //     emit(ProfileError(message: 'Failed to request gallery permission: $e'));
  //   }
}

  /// Handle record video selected
  // Future<void> _onRecordVideoSelected(
  //   RecordVideoSelected event,
  //   Emitter<ProfileState> emit,
  // ) async {
  //   emit(const RecordVideoMode());
  // }

  // /// Handle upload from gallery selected
  // Future<void> _onUploadFromGallerySelected(
  //   UploadFromGallerySelected event,
  //   Emitter<ProfileState> emit,
  // ) async {
  //   emit(const UploadFromGalleryMode());
  // }


