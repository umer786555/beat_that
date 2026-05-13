import 'package:image_picker/image_picker.dart';

class VideoPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Picks a video from the device camera
  /// Returns the video file if one was recorded, or null if cancelled/error
  /// Videos are saved to app cache and only persist temporarily.
  Future<XFile?> pickCameraVideo() async {
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

  /// Picks a video from the device gallery
  /// Returns the selected video file, or null if cancelled/error
  Future<XFile?> pickGalleryVideo() async {
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

  /// Picks a photo from the device gallery
  /// Returns the selected photo file, or null if cancelled/error
  /// Photos are saved to app cache and only persist temporarily.
  /// If you need to keep the photo, move it to a permanent location.
  Future<XFile?> pickGalleryPhoto() async {
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

