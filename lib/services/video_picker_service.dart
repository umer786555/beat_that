import 'package:image_picker/image_picker.dart';

class VideoPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Opens the camera to record a video and calls the callback with the selected video
  Future<void> openCameraAndHandleVideo(
    Function(XFile) onVideoSelected,
  ) async {
    final video = await _openCamera();

    if (video != null) {
      onVideoSelected(video);
    }
  }

  /// Opens the gallery to select a video and calls the callback with the selected video
  Future<void> openGalleryAndHandleVideo(
    Function(XFile) onVideoSelected,
  ) async {
    final video = await _openGallery();

    if (video != null) {
      onVideoSelected(video);
    }
  }

  /// Opens the device camera to record a video
  ///
  /// Returns the video file if one was recorded, or null if cancelled/error
  /// Videos are saved to app cache and only persist temporarily.
  /// If you need to keep the video, move it to a permanent location.
  Future<XFile?> _openCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      return video;
    } catch (e) {
      print('Error opening camera: $e');
      return null;
    }
  }

  /// Opens the device gallery to select a video
  ///
  /// Returns the selected video file, or null if cancelled/error
  Future<XFile?> _openGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      return video;
    } catch (e) {
      print('Error opening gallery: $e');
      return null;
    }
  }

  /// Opens the gallery to select a photo and calls the callback with the selected photo
  Future<void> openGalleryAndHandlePhoto(
    Function(XFile) onPhotoSelected,
  ) async {
    final photo = await _openGalleryForPhoto();

    if (photo != null) {
      onPhotoSelected(photo);
    }
  }

  /// Opens the device gallery to select a photo
  ///
  /// Returns the selected photo file, or null if cancelled/error
  /// Photos are saved to app cache and only persist temporarily.
  /// If you need to keep the photo, move it to a permanent location.
  Future<XFile?> _openGalleryForPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      return photo;
    } catch (e) {
      print('Error opening gallery for photo: $e');
      return null;
    }
  }
}

