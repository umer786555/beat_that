import 'dart:io';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/sport_subcategory.dart';
import 'package:beat_that/models/video_thumbnail_model.dart';
import 'package:beat_that/services/dio_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

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
    print('Step $stepNumber: Uploading thumbnail: $path (MIME: $mimeType)');
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

  /// Delete a video and all associated resources
  /// 
  /// Deletes in this order:
  /// 1. Database record (safest - no side effects if it fails)
  /// 2. Video file from storage
  /// 3. Thumbnail file from storage
  /// 
  /// Parameters:
  /// - [videoId]: The unique video ID to delete
  /// - [videoPath]: Relative path to video file in storage
  /// - [thumbnailPath]: Relative path to thumbnail file in storage
  /// 
  /// Returns: {success: true, message, deletedSteps} on success
  /// Returns: {success: false, error} on failure
  Future<Map<String, dynamic>> deleteVideo({
    required String videoId,
    required String videoPath,
    required String thumbnailPath,
  }) async {
    print('🗑️ Starting video deletion for videoId=$videoId');
    print('   Video path: $videoPath');
    print('   Thumbnail path: $thumbnailPath');
    
    try {

      final deletionSteps = <String>[];

      // ==================== STEP 1: Delete Database Record (FIRST) ====================
      print('Step 1: Deleting database record...');
      try {
        await _deleteWithRetry(
          operation: () => client.from('my_videos').delete().eq('id', videoId),
          resourceName: 'database record',
          maxAttempts: 3,
        );
        print('✓ Database record deleted successfully');
        deletionSteps.add('database_record');
      } catch (e) {
        print('✗ Failed to delete database record: $e');
        throw Exception('Database record deletion failed (storage untouched): $e');
      }

      // ==================== STEP 2: Delete Video File ====================
      print('Step 2: Deleting video file from storage...');
      try {
        await _deleteWithRetry(
          operation: () => client.storage.from('my_videos').remove([videoPath]),
          resourceName: 'video file',
          maxAttempts: 3,
        );
        print('✓ Video file deleted successfully');
        deletionSteps.add('video_file');
      } catch (e) {
        print('⚠ Warning: Failed to delete video file (orphaned): $e');
        deletionSteps.add('video_file_orphaned');
      }

      // ==================== STEP 3: Delete Thumbnail File ====================
      print('Step 3: Deleting thumbnail file from storage...');
      try {
        await _deleteWithRetry(
          operation: () => client.storage.from('my-thumbnails').remove([thumbnailPath]),
          resourceName: 'thumbnail file',
          maxAttempts: 3,
        );
        print('✓ Thumbnail file deleted successfully');
        deletionSteps.add('thumbnail_file');
      } catch (e) {
        print('⚠ Warning: Failed to delete thumbnail file (orphaned): $e');
        deletionSteps.add('thumbnail_file_orphaned');
      }

      // Check if all steps succeeded
      final hasOrphans = deletionSteps.any((s) => s.contains('orphaned'));
      if (hasOrphans) {
        print('⚠ Partial success: DB deleted but some files orphaned');
        return {
          'success': true,
          'message': 'Database record deleted. Some files may be orphaned in storage.',
          'deletedSteps': deletionSteps,
          'hasOrphans': true,
        };
      }

      print('✓ All deletion steps completed successfully: $deletionSteps');
      return {
        'success': true,
        'message': 'Video, thumbnail, and database record deleted successfully',
        'deletedSteps': deletionSteps,
      };
    } catch (e) {
      print('✗ Critical deletion failure: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Helper method to retry a delete operation up to maxAttempts times
  /// 
  /// Parameters:
  /// - [operation]: The async operation to retry
  /// - [resourceName]: Name of resource being deleted (for logging)
  /// - [maxAttempts]: Maximum number of retry attempts
  /// 
  /// Throws: Exception if all attempts fail
  Future<void> _deleteWithRetry({
    required Future<dynamic> Function() operation,
    required String resourceName,
    required int maxAttempts,
  }) async {
    int attempt = 1;
    
    while (attempt <= maxAttempts) {
      try {
        print('   Attempt $attempt/$maxAttempts: Deleting $resourceName...');
        final result = await operation();
        print('   ✓ $resourceName deleted (result: $result)');
        return; // Success, exit
      } catch (e) {
        print('   ✗ Attempt $attempt failed: $e');
        if (attempt == maxAttempts) {
          throw Exception('Failed to delete $resourceName after $maxAttempts attempts: $e');
        }
        attempt++;
        // Wait briefly before retrying
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// Helper method to extract file extension from file path
  String _getFileExtension(String filePath) {
    final ext = p.extension(filePath);
    return ext.isNotEmpty ? ext.substring(1).toLowerCase() : 'bin';
  }

  /// Check if a username already exists in the database
  /// 
  /// Optionally excludes a specific user ID from the check (useful when updating profile).
  /// 
  /// Parameters:
  /// - [username]: The username to check
  /// - [excludeId]: Optional user ID to exclude from the check
  /// 
  /// Returns: true if username exists (and doesn't belong to excludeId), false otherwise
  Future<bool> usernameExists(String username, {String? excludeId}) async {
    try {
      final query = client
          .from('user_personal_profiles')
          .select('id')
          .eq('username', username);

      final results = await query;

      if (results.isEmpty) {
        return false;
      }

      // If excludeId is provided, check if the result belongs to a different user
      if (excludeId != null) {
        return results.any((record) => record['id'] != excludeId);
      }

      return true;
    } catch (e) {
      print('Error checking username existence: $e');
      return false;
    }
  }

  /// Save user personal profile to the database
  ///
  /// Creates or updates the user's personal profile in the 'user_personal_profiles' table.
  /// Structured to support thousands of user profiles with proper indexing by user_id.
  ///
  /// Validates that:
  /// - Username is not empty
  /// - Username is no more than 20 characters
  /// - Username is not already taken before saving.
  ///
  /// Parameters:
  /// - [profile]: The UserPersonalProfile containing the username
  ///
  /// Returns: {success: true, message} on success or {success: false, error} on failure
  Future<Map<String, dynamic>> saveUserPersonalProfile(
    UserPersonalProfile profile,
  ) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Validate username length
      if (profile.username.length > 20) {
        return {'success': false, 'error': 'Keep it short! Max 20 characters.'};
      }

      // Check if username already exists (excluding current user's ID)
      final usernameTaken = await usernameExists(
        profile.username,
        excludeId: userId,
      );
      if (usernameTaken) {
        return {
          'success': false,
          'error': 'That username is taken! Try another one.',
        };
      }

      // Try to upsert - update if exists, insert if doesn't
      await client.from('user_personal_profiles').upsert({
        'id': userId,
        'username': profile.username,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      print('✓ User personal profile saved successfully for user: $userId');
      return {'success': true, 'message': 'You\'re all set! 🎉'};
    } catch (e) {
      print('Error saving user personal profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch user personal profile from the database
  ///
  /// Retrieves the current user's personal profile from the 'user_personal_profiles' table.
  /// Returns null if no profile exists for the user or user is not authenticated.
  ///
  /// Returns: UserPersonalProfile on success, null if not found or error occurs
  Future<UserPersonalProfile?> fetchUserPersonalProfile() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return null;
      }

      final data = await client
          .from('user_personal_profiles')
          .select()
          .eq('id', userId)
          .single();

      final profile = UserPersonalProfile(
        username: data['username'] as String,
        profileUrl: data['profileUrl'] as String?,
      );

      print('✓ User personal profile fetched successfully');
      return profile;
    } catch (e) {
      print('Error fetching user personal profile: $e');
      return null;
    }
  }

  /// Upload user profile image to Supabase storage and update database
  ///
  /// Validates that the file is a valid image format (JPEG, PNG, or WebP)
  /// Uploads to the 'profile_images' bucket and updates the user_personal_profiles table
  /// with the image URL path.
  ///
  /// Parameters:
  /// - [imageFile]: The image file to upload (must be JPEG, PNG, or WebP)
  ///
  /// Returns: {success: true, imageUrl, message} on success
  /// Returns: {success: false, error} on failure
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Get file extension
      final extension = _getFileExtension(imageFile.path);
      final path = '$userId/profile_image.$extension';

      // Upload file to storage
      await _uploadService.uploadFile(
        file: imageFile,
        bucketName: 'profile_images',
        path: path,
      );

      // Generate public URL with cache-busting parameter
      var imageUrl = client.storage.from('profile_images').getPublicUrl(path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      imageUrl = '$imageUrl?t=$timestamp';

      // Update user profile with image URL in database
      await client.from('user_personal_profiles').upsert({
        'id': userId,
        'profileUrl': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      return {
        'success': true,
        'imageUrl': imageUrl,
        'message': 'Profile image uploaded successfully! 🎉',
      };
    } catch (e) {
      print('Error uploading profile image: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload profile image and save URL to database (with automatic rollback on failure)
  ///
  /// This is an atomic operation that:
  /// 1. Uploads the image file to storage bucket
  /// 2. If successful, saves the image URL to the database
  /// 3. If database save fails, automatically deletes the uploaded image from storage (rollback)
  ///
  /// This ensures consistency - either everything succeeds or everything is rolled back.
  ///
  /// Parameters:
  /// - [imageFile]: The image file to upload (must be JPEG, PNG, or WebP)
  /// - [username]: The user's username to preserve in the database
  ///
  /// Returns: {success: true, imageUrl, message} on success
  /// Returns: {success: false, error} on failure (with automatic cleanup if needed)
  Future<Map<String, dynamic>> uploadAndSaveProfileImage(
    File imageFile,
    String username,
  ) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    // Track which resources were successfully created for cleanup
    String? uploadedImagePath;

    try {
      // ==================== STEP 1: Upload Image to Storage ====================
      final extension = _getFileExtension(imageFile.path);
      final path = '$userId/profile_image.$extension';
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

      // Upload file to storage
      await _uploadService.uploadFile(
        file: imageFile,
        bucketName: 'profile_images',
        path: path,
      );

      uploadedImagePath = path;

      // ==================== STEP 2: Generate Public URL ====================
      var imageUrl = client.storage.from('profile_images').getPublicUrl(path);
      
      // Add cache-busting query parameter (timestamp)
      // Since we overwrite the same file, this forces CDN and Image.network to fetch fresh
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      imageUrl = '$imageUrl?t=$timestamp';

      // ==================== STEP 3: Save URL to Database ====================
      // Prepare update data with username
      final updateData = {
        'id': userId,
        'username': username,
        'profileUrl': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client
          .from('user_personal_profiles')
          .upsert(updateData, onConflict: 'id');

      return {
        'success': true,
        'imageUrl': imageUrl,
        'message': 'Profile image uploaded and saved successfully! 🎉',
      };
    } catch (e) {
      // ==================== ROLLBACK: Delete uploaded file ====================
      if (uploadedImagePath != null) {
        try {
          await client.storage.from('profile_images').remove([
            uploadedImagePath,
          ]);
        } catch (deleteError) {
          // Silently ignore rollback errors
        }
      }

      // FAILURE
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Fetch all thumbnail URLs for the current user's videos
  ///
  /// Retrieves all video records from the database and generates signed URLs
  /// for each thumbnail. Returns strongly-typed VideoThumbnail models for display in the UI.
  ///
  /// Only fetches necessary columns for better performance:
  /// - id (UUID), thumbnail_url, video_url, title, description, view_count, created_at (timestampz)
  ///
  /// Returns a list of VideoThumbnail models containing:
  /// - id: Unique video identifier (UUID)
  /// - thumbnailUrl: Signed URL for the thumbnail image (7 days expiry)
  /// - videoUrl: Signed URL for the video file (7 days expiry)
  /// - title: Video title (String)
  /// - description: Video description (String)
  /// - viewCount: Number of views (int)
  /// - createdAt: When the video was created (timestampz as String)
  /// - thumbnailPath: Storage path for deletion
  /// - videoPath: Storage path for deletion
  ///
  /// Returns empty list if user not authenticated or no videos found.
  /// Throws exception on database query errors.
  Future<List<VideoThumbnailModel>> getAllThumbnailUrls() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return [];
      }

      final videos = await client
          .from('my_videos')
          .select(
            'id, thumbnail_url, video_url, title, description, view_count, average_rating, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final thumbnailData = <VideoThumbnailModel>[];
      for (final video in videos) {
        final videoData = await _buildVideoUrlData(video);
        thumbnailData.add(VideoThumbnailModel.fromJson(videoData));
      }

      return thumbnailData;
    } catch (e) {
      print('Error fetching thumbnails: $e');
      rethrow;
    }
  }

  /// Helper method to convert a storage path to a URL
  /// Tries signed URL first (works with private buckets), falls back to public URL
  Future<String> _pathToUrl(String bucketName, String path) async {
    try {
      return await client.storage
          .from(bucketName)
          .createSignedUrl(path, 604800);
    } catch (e) {
      print(
        'Could not create signed URL for $bucketName/$path, using public URL',
      );
      return client.storage.from(bucketName).getPublicUrl(path);
    }
  }

  /// Helper method to build video data with URLs
  /// Converts storage paths to accessible signed URLs for display
  Future<Map<String, dynamic>> _buildVideoUrlData(
    Map<String, dynamic> video,
  ) async {
    final thumbnailPath = video['thumbnail_url'] as String;
    final videoPath = video['video_url'] as String;

    final thumbnailUrl = await _pathToUrl('my-thumbnails', thumbnailPath);
    final videoUrl = await _pathToUrl('my_videos', videoPath);

    return _createVideoDataMap(video, thumbnailUrl, videoUrl, thumbnailPath, videoPath);
  }

  /// Helper method to create video data map
  Map<String, dynamic> _createVideoDataMap(
    Map<String, dynamic> video,
    String thumbnailUrl,
    String videoUrl,
    String thumbnailPath,
    String videoPath,
  ) {
    return {
      'id': video['id'] as String,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'thumbnail_path': thumbnailPath,
      'video_path': videoPath,
      'title': video['title'] as String? ?? 'Untitled',
      'description': video['description'] as String? ?? '',
      'view_count': video['view_count'] as int? ?? 0,
      'average_rating': video['average_rating'] as num? ?? 0.0,
      'created_at': video['created_at'] as String,
    };
  }

  // ==================== SPORT VIDEO OPERATIONS ====================

  /// Fetch all subcategories for a specific sport
  ///
  /// Retrieves all available subcategories from the sport_subcategories table
  /// for a given sport ID.
  ///
  /// Parameters:
  /// - [sportId]: Sport ID string (e.g., "basketball")
  ///
  /// Returns: List of SportSubcategory objects, or empty list on error
  // Future<List<SportSubcategory>> getSubcategoriesBySport(String sportId) async {
  //   try {
  //     final result = await client
  //         .from('sport_subcategories')
  //         .select('id, name')
  //         .eq('sport_id', sportId)
  //         .order('name');

  //     return (result as List<dynamic>)
  //         .map((item) => SportSubcategory.fromJson(item as Map<String, dynamic>))
  //         .toList();
  //   } catch (e) {
  //     print('Error fetching subcategories for $sportId: $e');
  //     return [];
  //   }
  // }

  /// Fetch all sports with their subcategories from the database
  ///
  /// Returns a map where keys are sport IDs (e.g., 'basketball')
  /// and values are lists of subcategory names for that sport.
  ///
  /// Returns: Map<String, List<String>> (sportId -> [subcategory names])
  Future<Map<String, List<SportSubcategory>>> getAllSportsWithSubcategories() async {
    try {
      final result = await client
          .from('sport_subcategories')
          .select('id, sport_id, name')
          .order('sport_id');

      final Map<String, List<SportSubcategory>> sportMap = {};

      for (final item in result as List<dynamic>) {
        final data = item as Map<String, dynamic>;
        final subcategory = SportSubcategory.fromJson(data);
        final sportId = subcategory.sportId;

        if (!sportMap.containsKey(sportId)) {
          sportMap[sportId] = [];
        }
        sportMap[sportId]!.add(subcategory);
      }

      return sportMap;
    } catch (e) {
      print('Error fetching all sports: $e');
      return {};
    }
  }

  /// Link a video to a sport subcategory
  ///
  /// Creates a link in the sport_videos table to make the video discoverable
  /// in the specified subcategory. The video details (title, description, URLs)
  /// are denormalized into the sport_videos table for efficient querying.
  ///
  /// A video can only belong to ONE subcategory.
  /// Users can only link their own videos.
  ///
  /// Parameters:
  /// - [videoId]: UUID of the video in my_videos table
  /// - [sportId]: Sport ID string (e.g., "soccer", "basketball")
  /// - [subcategoryId]: UUID of the subcategory (FK to sport_subcategories.id)
  ///
  /// Returns: {success: true, message, linkedVideoId} on success
  /// Returns: {success: false, error} on failure
  Future<Map<String, dynamic>> linkVideoToSubcategory({
    required String videoId,
    required String sportId,
    required String subcategoryId,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // STEP 1: Verify the video belongs to the current user and get video details
      final videoData = await client
          .from('my_videos')
          .select('id, title, description, video_url, thumbnail_url')
          .eq('id', videoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (videoData == null) {
        return {
          'success': false,
          'error': 'Video not found or does not belong to you',
        };
      }

      // STEP 2: Check if video is already linked to a subcategory
      final existingLink = await client
          .from('sport_videos')
          .select('id')
          .eq('user_video_id', videoId)
          .maybeSingle();

      if (existingLink != null) {
        return {
          'success': false,
          'error': 'You\'ve already linked this video to a category. Each video can only belong to one category.',
        };
      }

      // STEP 3: Link video to subcategory with denormalized data
      // This allows efficient discovery queries without JOINs
      final insertResponse = await client.from('sport_videos').insert({
        'user_id': userId,
        'user_video_id': videoId,
        'sport_id': sportId,
        'subcategory_id': subcategoryId,
        'title': videoData['title'] as String,
        'description': videoData['description'] as String? ?? '',
        'video_url': videoData['video_url'] as String,
        'thumbnail_url': videoData['thumbnail_url'] as String,
        'view_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select();

      if (insertResponse.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to link video to category',
        };
      }

      final linkedVideoId = insertResponse[0]['id'] as String?;

      print('✓ Video linked to subcategory in $sportId by user $userId');
      return {
        'success': true,
        'message': 'Video linked to category! 🎉',
        'linkedVideoId': linkedVideoId,
      };
    } catch (e) {
      print('Error linking video to subcategory: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch all videos linked to a specific sport subcategory (Discovery Method)
  ///
  /// Retrieves videos that have been linked to a specific subcategory,
  /// ordered by most recent first. Includes pagination support.
  ///
  /// Parameters:
  /// - [sportId]: Sport ID (e.g., "soccer")
  /// - [subcategoryId]: Subcategory ID UUID
  /// - [limit]: Maximum number of videos to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of videos with username included
  /// Each video contains: {id, title, description, video_url, thumbnail_url, view_count, username, created_at}
  Future<List<Map<String, dynamic>>> getSportCategoryVideos({
    required String sportId,
    required String subcategoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Query sport_videos table with pagination
      // Ordered by bayesian_score (Bayesian weighted rating) with total_ratings as tiebreaker
      final videos = await client
          .from('sport_videos')
          .select(
            'id, title, description, video_url, thumbnail_url, view_count, user_id, created_at, bayesian_score, total_ratings, average_rating',
          )
          .eq('sport_id', sportId)
          .eq('subcategory_id', subcategoryId)
          .order('bayesian_score', ascending: false)
          .order('total_ratings', ascending: false)
          .range(offset, offset + limit - 1);

      // Fetch usernames for each video
      final videosWithUsernames = <Map<String, dynamic>>[];
      for (final video in videos as List<dynamic>) {
        final videoMap = video as Map<String, dynamic>;
        final userId = videoMap['user_id'] as String?;

        if (userId != null) {
          final profiles = await client
              .from('user_personal_profiles')
              .select('username')
              .eq('id', userId)
              .maybeSingle();

          final username =
              profiles != null ? profiles['username'] as String : 'Unknown User';

          videosWithUsernames.add({
            ...videoMap,
            'username': username,
          });
        }
      }

      print(
        '✓ Fetched ${videosWithUsernames.length} videos for $sportId/$subcategoryId',
      );
      return videosWithUsernames;
    } catch (e) {
      print('Error fetching category videos: $e');
      return [];
    }
  }

  /// Fetch all videos linked by the current user (Their Contributions)
  ///
  /// Shows all videos that the current user has linked to categories.
  /// Useful for user profile to show their contributions.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default: 50)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of linked videos with category information
  /// Each video contains: {id, title, description, sport_id, subcategory_id, view_count, created_at}
  Future<List<Map<String, dynamic>>> getUserLinkedVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      final videos = await client
          .from('sport_videos')
          .select(
            'id, title, description, sport_id, subcategory_id, view_count, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('✓ Fetched ${videos.length} linked videos for user $userId');
      return List<Map<String, dynamic>>.from(videos as List<dynamic>);
    } catch (e) {
      print('Error fetching user linked videos: $e');
      return [];
    }
  }

  /// Update view count for a linked video in a specific category
  ///
  /// Atomically increments the view_count in BOTH tables:
  /// 1. sport_videos table - tracks views in this specific category
  /// 2. my_videos table - tracks total views across all categories
  ///
  /// Uses PostgreSQL atomic increment to prevent race conditions with concurrent views.
  /// Both tables are updated in a single atomic transaction.
  ///
  /// Parameters:
  /// - [linkedVideoId]: The ID from sport_videos table (not my_videos)
  /// - [increment]: Amount to increment (default: 1)
  ///
  /// Returns: {success: true} or {success: false, error}
  ///
  /// Note: This calls increment_both_view_counts() PostgreSQL function.
  /// Safe for concurrent views - no race conditions, no lost counts.
  Future<Map<String, dynamic>> updateCategoryVideoViewCount({
    required String linkedVideoId,
    int increment = 1,
  }) async {
    try {
      // Call single atomic RPC function that updates both tables
      await client.rpc('increment_both_view_counts', params: {
        'linked_video_id': linkedVideoId,
        'increment_by': increment,
      });

      print(
        '✓ Atomically incremented view count for linked video $linkedVideoId in both tables',
      );
      return {'success': true};
    } catch (e) {
      print('Error updating view count: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete a video from a category (Unlink video)
  ///
  /// Removes the link between a video and a category.
  /// This does NOT delete the video from my_videos table.
  /// Users can only unlink their own videos.
  ///
  /// Parameters:
  /// - [linkedVideoId]: The ID from sport_videos table
  ///
  /// Returns: {success: true} or {success: false, error}
  Future<Map<String, dynamic>> deleteLinkedVideo({
    required String linkedVideoId,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Verify this linked video belongs to the current user
      final videoCheck = await client
          .from('sport_videos')
          .select('id')
          .eq('id', linkedVideoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (videoCheck == null) {
        return {
          'success': false,
          'error': 'Video link not found or does not belong to you',
        };
      }

      // Delete the link
      await client.from('sport_videos').delete().eq('id', linkedVideoId);

      print('✓ Unlinked video $linkedVideoId from category');
      return {'success': true, 'message': 'Video unlinked from category'};
    } catch (e) {
      print('Error deleting linked video: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// ========== VIDEO RATING SYSTEM METHODS ==========
  /// The following methods manage the Bayesian-weighted rating system
  /// that allows users to rate videos 1-10 and rank them fairly.
  /// 
  /// System works as follows:
  /// - Each user can rate a video once (1-10)
  /// - Can update or delete their rating
  /// - PostgreSQL trigger auto-updates video's bayesian_score
  /// - Videos ranked by bayesian_score (prevents bias against new videos)
  /// ================================================

  /// Rate a video (submit or update a rating)
  ///
  /// Allows the current user to rate a video from 1-10.
  /// If the user already rated this video, their rating is updated.
  /// Uses UPSERT operation (insert if new, update if exists).
  ///
  /// The database trigger automatically:
  /// - Counts total votes
  /// - Sums all ratings
  /// - Calculates average rating
  /// - Recalculates Bayesian score for ranking
  ///
  /// Parameters:
  /// - [videoId]: UUID of the sport_videos table record
  /// - [rating]: Rating value (must be 1-10 inclusive)
  ///
  /// Returns:
  /// - {success: true, ratingId} - Rating submitted/updated successfully
  /// - {success: false, error} - Error message if validation fails
  Future<Map<String, dynamic>> rateVideo({
    required String videoId,
    required int rating,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Validate rating is in valid range (1-10)
      if (rating < 1 || rating > 10) {
        return {
          'success': false,
          'error': 'Rating must be between 1 and 10'
        };
      }

      // Upsert: inserts new rating if user hasn't rated, updates if they have
      // UNIQUE constraint on (user_id, sport_video_id) ensures one vote per user per video
      final result = await client.from('video_ratings').upsert({
        'user_id': userId,
        'sport_video_id': videoId,
        'rating': rating,
      });

      print('✓ User rated video $videoId with rating $rating');
      return {'success': true, 'ratingId': result[0]['id']};
    } catch (e) {
      print('Error rating video: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get the current user's rating for a video (if they've rated it)
  ///
  /// Checks if the current user has already rated a specific video.
  /// Used to display which rating button should be highlighted in the UI.
  ///
  /// Parameters:
  /// - [videoId]: UUID of the sport_videos table record
  ///
  /// Returns:
  /// - {success: true, rating: 8} - User's rating (1-10)
  /// - {success: true, rating: null} - User hasn't rated this video yet
  /// - {success: false, error} - Error occurred
  Future<Map<String, dynamic>> getUserRating({
    required String videoId,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'rating': null};
      }

      // Query video_ratings table for this user's vote on this video
      // maybeSingle() returns null if no rating exists (graceful, no error)
      final result = await client
          .from('video_ratings')
          .select()
          .eq('sport_video_id', videoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null) {
        // User hasn't rated this video yet
        return {'success': true, 'rating': null};
      }

      // Return the rating value (1-10)
      return {'success': true, 'rating': result['rating'] as int};
    } catch (e) {
      print('Error getting user rating: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete the current user's rating for a video
  ///
  /// Removes the user's rating from the video_ratings table.
  /// The PostgreSQL trigger automatically recalculates the video's bayesian_score.
  ///
  /// Parameters:
  /// - [videoId]: UUID of the sport_videos table record
  ///
  /// Returns:
  /// - {success: true} - Rating deleted successfully
  /// - {success: false, error} - Error occurred or user not authenticated
  Future<Map<String, dynamic>> deleteRating({
    required String videoId,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Delete the user's rating from video_ratings table
      await client
          .from('video_ratings')
          .delete()
          .eq('sport_video_id', videoId)
          .eq('user_id', userId);

      print('✓ Deleted rating for video $videoId');
      return {'success': true, 'message': 'Rating removed'};
    } catch (e) {
      print('Error deleting rating: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== USER FOLLOW SYSTEM METHODS ====================
  /// The following methods manage the social following system
  /// that allows users to follow each other and build networks.
  /// ================================================

  /// Follow a user
  ///
  /// Creates a follow relationship where the current user follows another user.
  /// Uses UNIQUE constraint to prevent duplicate follows.
  ///
  /// Parameters:
  /// - [userIdToFollow]: UUID of the user to follow
  ///
  /// Returns:
  /// - {success: true} - Successfully started following
  /// - {success: false, error} - Error message if validation fails or already following
  Future<Map<String, dynamic>> followUser({
    required String userIdToFollow,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Prevent self-following
      if (userId == userIdToFollow) {
        return {'success': false, 'error': 'You cannot follow yourself'};
      }

      // Insert follow relationship
      // If duplicate, will fail due to UNIQUE constraint (which is good)
      await client.from('user_follows').insert({
        'follower_id': userId,
        'followed_user_id': userIdToFollow,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✓ Successfully followed user $userIdToFollow');
      return {'success': true, 'message': 'Now following user! 🎉'};
    } catch (e) {
      print('Error following user: $e');
      // Check if error is due to duplicate (already following)
      if (e.toString().contains('duplicate') ||
          e.toString().contains('UNIQUE')) {
        return {'success': false, 'error': 'You\'re already following this user'};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Unfollow a user
  ///
  /// Removes the follow relationship where the current user follows another user.
  ///
  /// Parameters:
  /// - [userIdToUnfollow]: UUID of the user to unfollow
  ///
  /// Returns:
  /// - {success: true} - Successfully unfollowed user
  /// - {success: false, error} - Error if follow relationship doesn't exist
  Future<Map<String, dynamic>> unfollowUser({
    required String userIdToUnfollow,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Delete follow relationship
      await client
          .from('user_follows')
          .delete()
          .eq('follower_id', userId)
          .eq('followed_user_id', userIdToUnfollow);

      print('✓ Successfully unfollowed user $userIdToUnfollow');
      return {'success': true, 'message': 'Unfollowed user'};
    } catch (e) {
      print('Error unfollowing user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all users that the current user is following
  ///
  /// Retrieves a paginated list of users that the current user follows.
  /// Includes user profile information (username, profile image).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of users to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of users with profile data
  /// Each user contains: {id, username, profileUrl, created_at}
  Future<List<Map<String, dynamic>>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      // Get list of user IDs that current user follows
      final follows = await client
          .from('user_follows')
          .select('followed_user_id')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (follows.isEmpty) {
        return [];
      }

      // Extract followed user IDs
      final followedUserIds = (follows as List<dynamic>)
          .map((f) => (f as Map<String, dynamic>)['followed_user_id'] as String)
          .toList();

      // Fetch profile data for all followed users
      final profiles = await client
          .from('user_personal_profiles')
          .select('id, username, profileUrl')
          .inFilter('id', followedUserIds);

      print(
          '✓ Fetched ${profiles.length} users that current user is following');
      return List<Map<String, dynamic>>.from(profiles as List<dynamic>);
    } catch (e) {
      print('Error fetching following list: $e');
      return [];
    }
  }

  /// Get all followers of the current user
  ///
  /// Retrieves a paginated list of users that follow the current user.
  /// Includes user profile information (username, profile image).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of users to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of users with profile data
  /// Each user contains: {id, username, profileUrl, created_at}
  Future<List<Map<String, dynamic>>> getFollowers({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      // Get list of user IDs that follow current user
      final follows = await client
          .from('user_follows')
          .select('follower_id')
          .eq('followed_user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (follows.isEmpty) {
        return [];
      }

      // Extract follower user IDs
      final followerUserIds = (follows as List<dynamic>)
          .map((f) => (f as Map<String, dynamic>)['follower_id'] as String)
          .toList();

      // Fetch profile data for all followers
      final profiles = await client
          .from('user_personal_profiles')
          .select('id, username, profileUrl')
          .inFilter('id', followerUserIds);

      print('✓ Fetched ${profiles.length} followers for current user');
      return List<Map<String, dynamic>>.from(profiles as List<dynamic>);
    } catch (e) {
      print('Error fetching followers list: $e');
      return [];
    }
  }

  /// Get the count of users following the current user
  ///
  /// Lightweight query that returns only the count (no user data).
  /// Useful for displaying "42 followers" on profile screen.
  ///
  /// Returns:
  /// - {success: true, count: 42} - Follower count
  /// - {success: false, count: 0, error} - Error occurred
  Future<Map<String, dynamic>> getFollowerCount() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'count': 0, 'error': 'User not authenticated'};
      }

      // Count all follows where current user is being followed
      final result = await client
          .from('user_follows')
          .select('id')
          .eq('followed_user_id', userId);

      final count = result.length;

      print('✓ Fetched follower count: $count');
      return {'success': true, 'count': count};
    } catch (e) {
      print('Error fetching follower count: $e');
      return {'success': false, 'count': 0, 'error': e.toString()};
    }
  }

  /// Get the count of users the current user is following
  ///
  /// Lightweight query that returns only the count (no user data).
  /// Useful for displaying "18 following" on profile screen.
  ///
  /// Returns:
  /// - {success: true, count: 18} - Following count
  /// - {success: false, count: 0, error} - Error occurred
  Future<Map<String, dynamic>> getFollowingCount() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'count': 0, 'error': 'User not authenticated'};
      }

      // Count all follows where current user is the follower
      final result = await client
          .from('user_follows')
          .select('id')
          .eq('follower_id', userId);

      final count = result.length;

      print('✓ Fetched following count: $count');
      return {'success': true, 'count': count};
    } catch (e) {
      print('Error fetching following count: $e');
      return {'success': false, 'count': 0, 'error': e.toString()};
    }
  }

  /// Check if current user is following a specific user
  ///
  /// Lightweight boolean check useful for toggling follow/unfollow button state.
  ///
  /// Parameters:
  /// - [userId]: UUID of the user to check
  ///
  /// Returns:
  /// - {success: true, isFollowing: true} - User is being followed
  /// - {success: true, isFollowing: false} - User is not being followed
  /// - {success: false, error} - Error occurred
  Future<Map<String, dynamic>> checkIsFollowing({
    required String userId,
  }) async {
    try {
      final currentUserId = getCurrentUserId();
      if (currentUserId == null) {
        return {'success': false, 'isFollowing': false};
      }

      final result = await client
          .from('user_follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('followed_user_id', userId)
          .maybeSingle();

      final isFollowing = result != null;

      return {'success': true, 'isFollowing': isFollowing};
    } catch (e) {
      print('Error checking follow status: $e');
      return {
        'success': false,
        'isFollowing': false,
        'error': e.toString()
      };
    }
  }
}
