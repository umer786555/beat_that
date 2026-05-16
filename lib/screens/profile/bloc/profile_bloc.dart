import 'package:beat_that/service_locator.dart';
import 'package:equatable/equatable.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  
  final permissionService = locator<PermissionService>();
  final supabaseService = locator<SupabaseService>();
  final authService = locator<AuthService>();
  
  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<LogoutEvent>(_onLogout);
    on<RequestCameraPermissionEvent>(_onRequestCameraPermission);
    on<RequestGalleryPermissionEvent>(_onRequestGalleryPermission);
    on<RecordVideoSelected>(_onRecordVideoSelected);
    on<UploadFromGallerySelected>(_onUploadFromGallerySelected);
    // on<CloseUploadModal>(_onCloseUploadModal);
  }

  /// Load profile data and fetch thumbnail URLs
  /// 
  /// This event performs two sequential operations:
  /// 1. Check camera and gallery permissions
  /// 2. Fetch all thumbnail URLs for the current user's videos
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

      // Initialize with permissions and thumbnails
      emit(
        ProfileLoaded(
          cameraPermissionEnabled: cameraPermissionEnabled,
          galleryPermissionEnabled: galleryPermissionEnabled,
          thumbnails: thumbnails,
        ),
      );
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.failedToLoadProfile}: $e'));
    }
  }

  /// Handle logout
  Future<void> _onLogout(LogoutEvent event, Emitter<ProfileState> emit) async {
    try {
      emit(ProfileLoading());
      await authService.logout();
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.logoutFailed}: $e'));
    }
  }

  /// Handle camera permission request
  Future<void> _onRequestCameraPermission(
    RequestCameraPermissionEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Check current permission status
      final status = await Permission.camera.status;

      if (status.isGranted) {
        // Permission already granted - update ProfileLoaded state
        emit((state as ProfileLoaded).copyWith(cameraPermissionEnabled: true));
        return;
      }

      // Request permission
      final permissionGranted =
          await PermissionService.requestCameraPermission();

      if (permissionGranted) {
        // Permission granted after request - update ProfileLoaded state
        emit((state as ProfileLoaded).copyWith(cameraPermissionEnabled: true));
      } else {
        // Permission denied - show permission denied state
        final finalStatus = await Permission.camera.status;
        emit(
          CameraPermissionDenied(
            isPermanentlyDenied: finalStatus.isPermanentlyDenied,
          ),
        );
      }
    } catch (e) {
      emit(ProfileError(message: 'Failed to request camera permission: $e'));
    }
  }

  /// Handle gallery permission request
  Future<void> _onRequestGalleryPermission(
    RequestGalleryPermissionEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Check current permission status
      final status = await Permission.photos.status;

      if (status.isGranted) {
        // Permission already granted - update ProfileLoaded state
        emit((state as ProfileLoaded).copyWith(galleryPermissionEnabled: true));
        return;
      }

      // Request permission
      final permissionGranted =
          await PermissionService.requestPhotosPermission();

      if (permissionGranted) {
        // Permission granted after request - update ProfileLoaded state
        emit((state as ProfileLoaded).copyWith(galleryPermissionEnabled: true));
      } else {
        // Permission denied - show permission denied state
        emit(
          (state as ProfileLoaded).copyWith(galleryPermissionEnabled: false),
        );
      }
    } catch (e) {
      emit(ProfileError(message: 'Failed to request gallery permission: $e'));
    }
  }

  /// Handle record video selected
  Future<void> _onRecordVideoSelected(
    RecordVideoSelected event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const RecordVideoMode());
  }

  /// Handle upload from gallery selected
  Future<void> _onUploadFromGallerySelected(
    UploadFromGallerySelected event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const UploadFromGalleryMode());
  }

}
