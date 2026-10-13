import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  /// Returns: true if granted, false otherwise
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return _handlePermissionStatus(status);
  }

  /// Request microphone permission
  /// Returns: true if granted, false otherwise
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return _handlePermissionStatus(status);
  }

  /// Request photos permission (gallery access)
  /// Returns: true if granted, false otherwise
  static Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();
    return _handlePermissionStatus(status);
  }

  /// Request both camera and microphone permissions
  /// Returns: true if both granted, false otherwise
  static Future<bool> requestCameraAndMicrophonePermission() async {
    final statuses = await [Permission.camera, Permission.microphone].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

    return cameraGranted && micGranted;
  }

  /// Check current camera permission status without requesting
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request photos access for picking an image from the gallery.
  /// Returns: true if full or limited (iOS) access is granted, false otherwise
  Future<bool> requestPhotosAccess() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// Check current microphone permission status without requesting
  static Future<bool> isMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Check current photos permission status without requesting
  static Future<bool> isPhotosPermissionGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// Open app settings for user to manually grant permissions
  // static Future<bool> openAppSettings() async {
  //  // return Permission.;
  // }

  /// Handle permission status and return user-friendly message
  static String getPermissionDenialMessage(Permission permission) {
    return '''
Camera access is required to record videos. 
Please enable it in app settings.
''';
  }

  /// Private helper to process PermissionStatus
  static bool _handlePermissionStatus(PermissionStatus status) {
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      return false;
    } else if (status.isRestricted) {
      // Parental controls or device restrictions
      return false;
    } else if (status.isPermanentlyDenied) {
      // User permanently denied, need to open app settings
      return false;
    }
    return false;
  }
}
