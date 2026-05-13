import 'dart:io';
import 'package:beat_that/services/dio_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:beat_that/service_locator.dart';

class SupabaseService {
  /// Get the Supabase client instance
  /// This accesses the globally initialized Supabase instance
  /// Supabase.initialize() must be called in main.dart before using
  static SupabaseClient get client => Supabase.instance.client;

  /// DioUploadService for handling file uploads with progress tracking
  late final DioUploadService _uploadService;

  /// Initialize SupabaseService with dependencies
  SupabaseService() {
    _uploadService = locator<DioUploadService>();
  }

  /// Get current authenticated user ID
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  /// Get current authenticated user email
  String? getCurrentUserEmail() {
    return client.auth.currentUser?.email;
  }

  /// Upload video with thumbnail to Supabase storage and create database record
  ///
  /// This is an atomic operation with 4 steps:
  /// - Step 1: Upload video file to storage (with progress tracking)
  /// - Step 2: Upload thumbnail file to storage
  /// - Step 3: Create database record with validation
  /// - Step 4: Generate public URLs
  ///
  /// Supports any video format (MP4, WebM, MOV, etc.) and image format (JPEG, PNG, WebP, etc.)
  /// MIME types are automatically detected from file extensions.
  ///
  /// Note: Only video upload progress is tracked. Thumbnails are tiny and upload instantly.
  ///
  /// Parameters:
  /// - [videoFile]: The video file to upload (any video format)
  /// - [thumbnailFile]: The thumbnail image file to upload (any image format)
  /// - [title]: Video title for the database record
  /// - [description]: Video description (optional)
  /// - [onVideoProgress]: Callback for video upload progress (sent, total)
  ///
  /// Returns on success:
  /// - {success: true, fileId, videoId, videoUrl, thumbnailUrl, videoPath, thumbnailPath, message}
  ///
  /// Returns on failure:
  /// - {success: false, message, error}
  /// - All uploaded files and database records are automatically deleted on failure
  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required File videoFile,
    required File thumbnailFile,
    required String title,
    String? description,
    Function(int, int)? onVideoProgress,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      return {
        'success': false,
        'message': 'Error: User not authenticated',
        'error': 'User is not logged in',
      };
    }

    // Generate unique file ID
    const uuid = Uuid();
    final fileId = uuid.v4();

    // Track which files were successfully uploaded for cleanup
    String? uploadedVideoPath;
    String? uploadedThumbnailPath;
    String? createdVideoId;

    try {
      // ==================== STEP 1: Upload Video ====================
      print('Step 1: Uploading video file...');
      final videoUploadData = await _uploadVideoFile(
        file: videoFile,
        userId: userId,
        fileId: fileId,
        stepNumber: 1,
        onProgress: onVideoProgress,
      );
      uploadedVideoPath = videoUploadData['path'] as String;
      final videoPath = videoUploadData['path'] as String;

      // ==================== STEP 2: Upload Thumbnail ====================
      print('Step 2: Uploading thumbnail file...');
      final thumbnailUploadData = await _uploadThumbnailFile(
        file: thumbnailFile,
        userId: userId,
        fileId: fileId,
        stepNumber: 2,
      );
      uploadedThumbnailPath = thumbnailUploadData['path'] as String;
      final thumbnailPath = thumbnailUploadData['path'] as String;

      // ==================== STEP 3: Create Database Record ====================
      print('Step 3: Creating video record in database');
      final insertResponse = await client.from('my_videos').insert({
        'user_id': userId,
        'title': title,
        'description': description ?? '',
        'video_url': videoPath,
        'thumbnail_url': thumbnailPath,
        'view_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'data_type': 'user_profile_video',
      }).select();

      // Validate database insert response
      if (insertResponse.isEmpty) {
        throw Exception('Database insert failed: empty response');
      }

      createdVideoId = insertResponse[0]['id'] as String?;
      if (createdVideoId == null || createdVideoId.isEmpty) {
        throw Exception('Database insert failed: missing or invalid video ID');
      }

      print('✓ Database record created successfully');
      print('File ID: $fileId');

      // ==================== STEP 4: Generate Public URLs ====================
      final videoPublicUrl = client.storage
          .from('my_videos')
          .getPublicUrl(videoPath);

      final thumbnailPublicUrl = client.storage
          .from('my-thumbnails')
          .getPublicUrl(thumbnailPath);

      print('✓ All steps completed successfully!');
      print('Video URL: $videoPublicUrl');
      print('Thumbnail URL: $thumbnailPublicUrl');
      print('Video ID: $createdVideoId');

      // SUCCESS
      return {
        'success': true,
        'fileId': fileId,
        'videoId': createdVideoId,
        'videoUrl': videoPublicUrl,
        'thumbnailUrl': thumbnailPublicUrl,
        'videoPath': videoPath,
        'thumbnailPath': thumbnailPath,
        'message': 'Video and thumbnail uploaded successfully',
      };
    } catch (e) {
      print('✗ Operation failed: $e');
      print('Rolling back all changes...');

      // ==================== ROLLBACK: Delete uploaded files ====================
      if (uploadedVideoPath != null) {
        try {
          print('Deleting uploaded video file...');
          await client.storage.from('my_videos').remove([uploadedVideoPath]);
          print('✓ Video file deleted');
        } catch (deleteError) {
          print('⚠ Warning: Could not delete video file: $deleteError');
        }
      }

      if (uploadedThumbnailPath != null) {
        try {
          print('Deleting uploaded thumbnail file...');
          await client.storage.from('my-thumbnails').remove([
            uploadedThumbnailPath,
          ]);
          print('✓ Thumbnail file deleted');
        } catch (deleteError) {
          print('⚠ Warning: Could not delete thumbnail file: $deleteError');
        }
      }

      // ==================== ROLLBACK: Delete database record ====================
      if (createdVideoId != null) {
        try {
          print('Deleting database record...');
          await client.from('my_videos').delete().eq('id', createdVideoId);
          print('✓ Database record deleted');
        } catch (deleteError) {
          print('⚠ Warning: Could not delete database record: $deleteError');
        }
      }

      // FAILURE
      return {
        'success': false,
        'message': 'Upload failed and rolled back',
        'error': e.toString(),
      };
    }
  }

  /// Helper method to upload a video file to Supabase storage
  ///
  /// Handles: extension detection, path construction, MIME type detection, and upload
  /// Uses DioUploadService for progress tracking capability
  ///
  /// Parameters:
  /// - [file]: Video file to upload
  /// - [userId]: User ID for path construction
  /// - [fileId]: Unique file ID
  /// - [stepNumber]: Step number for logging
  /// - [onProgress]: Optional progress callback (sent, total)
  ///
  /// Returns: {path: String, mimeType: String}
  Future<Map<String, dynamic>> _uploadVideoFile({
    required File file,
    required String userId,
    required String fileId,
    required int stepNumber,
    Function(int, int)? onProgress,
  }) async {
    final extension = _getFileExtension(file.path);
    final path = 'profiles/$userId/videos/$fileId.$extension';
    final mimeType = lookupMimeType(file.path) ?? 'video/mp4';

    final sizeInBytes = file.lengthSync();
    final sizeInMB = sizeInBytes / (1000 * 1000);
    print('Step $stepNumber: Uploading video: $path (MIME: $mimeType)');
    print('Video size: ${sizeInMB.toStringAsFixed(2)} MB');

    // Use class-level DioUploadService with progress tracking
    await _uploadService.uploadFile(
      file: file,
      bucketName: 'my_videos',
      path: path,
      onProgress: onProgress,
    );

    print('✓ Video uploaded successfully');
    return {'path': path, 'mimeType': mimeType};
  }

  /// Helper method to upload a thumbnail file to Supabase storage
  ///
  /// Handles: extension detection, path construction, MIME type detection, and upload
  /// Uses DioUploadService for file upload
  ///
  /// Parameters:
  /// - [file]: Thumbnail file to upload
  /// - [userId]: User ID for path construction
  /// - [fileId]: Unique file ID
  /// - [stepNumber]: Step number for logging
  ///
  /// Returns: {path: String, mimeType: String}
  Future<Map<String, dynamic>> _uploadThumbnailFile({
    required File file,
    required String userId,
    required String fileId,
    required int stepNumber,
  }) async {
    final extension = _getFileExtension(file.path);
    final path = 'profiles/$userId/thumbnails/${fileId}_thumb.$extension';
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

    final sizeInBytes = file.lengthSync();
    final sizeInMB = sizeInBytes / (1000 * 1000);
    print(
      'Step $stepNumber: Uploading thumbnail: $path (MIME: $mimeType)',
    );
    print('Thumbnail size: ${sizeInMB.toStringAsFixed(2)} MB');

    // Use class-level DioUploadService (no progress tracking - instant upload)
    await _uploadService.uploadFile(
      file: file,
      bucketName: 'my-thumbnails',
      path: path,
    );

    print('✓ Thumbnail uploaded successfully');
    return {'path': path, 'mimeType': mimeType};
  }

  /// Helper method to extract file extension from file path
  String _getFileExtension(String filePath) {
    final ext = p.extension(filePath);
    return ext.isNotEmpty ? ext.substring(1).toLowerCase() : 'bin';
  }

  /// Get current user's profile
  ///
  /// Fetches user profile from the profiles table.
  ///
  /// Returns: User profile map with all fields, or null if not found or user not authenticated
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final profile = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return profile;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Check if user is authenticated
  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  /// Get user session
  Session? getSession() {
    return client.auth.currentSession;
  }
}
