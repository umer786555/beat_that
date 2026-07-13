import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/video_thumbnail_model.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final permissionService = locator<PermissionService>();
  final supabaseService = locator<SupabaseService>();
  final authService = locator<AuthService>();
  final preferencesService = locator<PreferencesService>();
  final videoPickerService = locator<VideoPickerService>();

  // Cache user profile at block level for access across all handlers
  late UserPersonalProfile? userProfile;

  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<AddProfileImageEvent>(_onAddProfileImage);
    on<DeleteVideoEvent>(_onDeleteVideo);
    on<RefreshVideosEvent>(_onRefreshVideos);
  }

  /// Load profile data and fetch thumbnail URLs
  ///
  /// This event performs four sequential operations:
  /// 1. Check camera and gallery permssions
  /// 2. Fetch all thumbnail URLs for the current user's videos
  /// 3. Fetch the username from preferences
  /// 4. Fetch the follower and following counts
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

      // Step 2: Fetch all thumbnail URLs
      final thumbnails = await supabaseService.getAllThumbnailUrls();

      // Step 3: Fetch the username from preferences and cache at block level
      userProfile = await preferencesService.fetchUserProfile();

      // Step 4: Fetch the follower and following counts
      final followerCountResult = await supabaseService.getFollowerCount();
      final followingCountResult = await supabaseService.getFollowingCount();

      final followers = followerCountResult['success'] ? followerCountResult['count'] : 786;
      final following = followingCountResult['success'] ? followingCountResult['count'] : 786;

      // Initialize with permissions, thumbnails, username, and follower/following counts
      emit(
        ProfileLoaded(
          cameraPermissionEnabled: cameraPermissionEnabled,
          galleryPermissionEnabled: galleryPermissionEnabled,
          thumbnails: thumbnails,
          username: userProfile?.username,
          profileUrl: userProfile?.profileUrl,
          followers: followers,
          following: following,
        ),
      );
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.failedToLoadProfile}: $e'));
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
  /// Deletes video file, thumbnail, and database record
  Future<void> _onDeleteVideo(
    DeleteVideoEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Save current state before emitting loading
      final previousState = state;
      emit(ProfileLoading());

      // Delete video with thumbnail and database record
      final deleteResult = await supabaseService.deleteVideo(
        videoId: event.videoId,
        videoPath: event.videoPath,
        thumbnailPath: event.thumbnailPath,
      );

      if (deleteResult['success']) {
        // Fetch updated thumbnails list after deletion
        final updatedThumbnails = await supabaseService.getAllThumbnailUrls();

        // Emit success with updated thumbnails
        if (previousState is ProfileLoaded) {
          emit(previousState.copyWith(thumbnails: updatedThumbnails));
        } else {
          // Fallback if state is not ProfileLoaded - reload entire profile
          final updatedProfile = await supabaseService
              .fetchUserPersonalProfile();
          if (updatedProfile != null) {
            userProfile = updatedProfile;
            emit(
              ProfileLoaded(
                cameraPermissionEnabled: previousState is ProfileLoaded
                    ? (previousState).cameraPermissionEnabled
                    : false,
                galleryPermissionEnabled: previousState is ProfileLoaded
                    ? (previousState).galleryPermissionEnabled
                    : false,
                thumbnails: updatedThumbnails,
                username: updatedProfile.username,
                profileUrl: updatedProfile.profileUrl,
              ),
            );
          }
        }
      } else {
        emit(
          ProfileError(
            message:
                'Failed to delete video: ${deleteResult['error'] ?? 'Unknown error'}',
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error in _onDeleteVideo: $e');
      print('Stack trace: $stackTrace');
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
      final updatedThumbnails = await supabaseService.getAllThumbnailUrls();

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


