import 'dart:io';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/models/user_block.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/user_profile_summary.dart';
import 'package:beat_that/models/sport_subcategory.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/models/video_rating.dart';
import 'package:beat_that/services/dio_upload_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

class SupabaseService {
  static const String _debugMediaPrefix = '[DEBUG_MEDIA]';
  static const int _profileImageMaxDimension = 1080;
  static const int _profileImageQuality = 78;
  static const int _thumbnailMaxDimension = 720;
  static const int _thumbnailQuality = 80;
  static const VideoQuality _videoCompressionQuality =
      VideoQuality.HighestQuality;

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

  /// Subscribe to real-time approval status changes for the current user's videos
  ///
  /// Returns a RealtimeChannel that listens for UPDATE events on the my_videos table.
  /// The callback receives the updated video record when the approved field changes.
  ///
  /// The channel should be unsubscribed when no longer needed to avoid memory leaks.
  /// Best practice: Store the channel reference and unsubscribe in bloc close().
  ///
  /// Payload structure:
  /// - payload.newRecord: Map containing updated row with id and approved fields
  /// - payload.oldRecord: Map containing previous values (if replica identity full is set)
  ///
  /// Example usage:
  /// ```dart
  /// final channel = supabaseService.subscribeToVideoApprovalChanges(
  ///   onApprovalChanged: (videoId, approvalStatus) {
  ///     // Handle the approval status change
  ///   },
  /// );
  /// // Later: await channel.unsubscribe();
  /// ```
  RealtimeChannel subscribeToVideoApprovalChanges({
    required Function(String videoId, bool? approvalStatus) onApprovalChanged,
  }) {
    return client
        .channel('my-videos-approval-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'my_videos',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              final videoId = newRecord['id'] as String?;
              final approvalStatus = newRecord['approved'] as bool?;

              if (videoId != null) {
                print(
                  '[REALTIME] Video approval updated: id=$videoId, approved=$approvalStatus',
                );
                onApprovalChanged(videoId, approvalStatus);
              }
            } catch (e) {
              print('[ERROR] Failed to process approval change: $e');
            }
          },
        )
        .subscribe();
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
  /// - {success: true, fileId, videoId, videoPath, thumbnailPath, videoPublicUrl, thumbnailUrl, message}
  ///
  /// Returns on failure:
  /// - {success: false, message, error}
  /// - All uploaded files and database records are automatically deleted on failure
  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required File videoFile,
    required File thumbnailFile,
    required String title,
    String? description,
    String? sportId,
    int? subcategoryId,
    String? subcategoryName,
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
    File? compressedVideoFile;
    File? compressedThumbnailFile;

    try {
      // ==================== STEP 1: Upload Video ====================
      print('Step 1: Uploading video file...');
      compressedVideoFile = await _compressVideoForUpload(
        videoFile,
        quality: _videoCompressionQuality,
      );
      final videoUploadData = await _uploadVideoFile(
        file: compressedVideoFile,
        userId: userId,
        fileId: fileId,
        stepNumber: 1,
        onProgress: onVideoProgress,
      );
      uploadedVideoPath = videoUploadData['path'] as String;
      final videoPath = videoUploadData['path'] as String;

      // ==================== STEP 2: Upload Thumbnail ====================
      print('Step 2: Uploading thumbnail file...');
      compressedThumbnailFile = await _compressImageForUpload(
        thumbnailFile,
        fileNamePrefix: 'upload_thumbnail',
        maxDimension: _thumbnailMaxDimension,
        quality: _thumbnailQuality,
      );
      print(
        '$_debugMediaPrefix Uploading thumbnail file to Supabase: ${compressedThumbnailFile.path} (${_formatBytes(await compressedThumbnailFile.length())})',
      );
      final thumbnailUploadData = await _uploadThumbnailFile(
        file: compressedThumbnailFile,
        userId: userId,
        fileId: fileId,
        stepNumber: 2,
      );
      uploadedThumbnailPath = thumbnailUploadData['path'] as String;
      final thumbnailPath = thumbnailUploadData['path'] as String;

      // ==================== STEP 3: Create Database Record ====================
      // Store paths only (not full URLs) - URLs generated on-demand by service layer
      // This follows industry best practice (Instagram, YouTube, etc.)
      print('Step 3: Creating video record in database');
      final insertResponse = await client
          .from('my_videos')
          .insert(
            MyVideo.createInsertJson(
              userId: userId,
              title: title,
              description: description,
              videoPath: videoPath,
              thumbnailPath: thumbnailPath,
              sportId: sportId,
              subcategoryId: subcategoryId,
              subcategoryName: subcategoryName,
            ),
          )
          .select();

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

      // ==================== STEP 4: Generate Public URLs (for return value only) ====================
      final videoPublicUrl = _generatePublicUrl('my_videos', videoPath);
      final thumbnailPublicUrl = ('my-thumbnails', thumbnailPath);

      print('✓ All steps completed successfully!');
      print('Video URL: $videoPublicUrl');
      print('Thumbnail URL: $thumbnailPublicUrl');
      print('Video ID: $createdVideoId');

      // SUCCESS
      return {
        'success': true,
        'fileId': fileId,
        'videoId': createdVideoId,
        'videoPublicUrl': videoPublicUrl,
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
    } finally {
      await _deleteTemporaryCompressedFile(compressedVideoFile, videoFile);
      await _deleteTemporaryCompressedFile(
        compressedThumbnailFile,
        thumbnailFile,
      );
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
    final path = '$userId/videos/$fileId.$extension';
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
    final path = '$userId/thumbnails/${fileId}_thumb.$extension';
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
        throw Exception(
          'Database record deletion failed (storage untouched): $e',
        );
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
          operation: () =>
              client.storage.from('my-thumbnails').remove([thumbnailPath]),
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
          'message':
              'Database record deleted. Some files may be orphaned in storage.',
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
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete the current user's video via the `delete-my-video` Edge Function.
  ///
  /// This is the client-side caller only. The actual deletion logic lives in
  /// the Supabase Edge Function and should validate ownership, remove storage
  /// assets, and delete related database rows server-side.
  ///
  /// Parameters:
  /// - [videoId]: The UUID of the `my_videos` record to delete
  ///
  /// Returns:
  /// - {success: true, status, data} on success
  /// - {success: false, error, status?} on failure
  Future<Map<String, dynamic>> deleteMyVideoViaEdgeFunction({
    required String videoId,
  }) async {
    try {
      print('delete-video request videoId=$videoId');

      final response = await _invokeAuthenticatedEdgeFunction(
        'delete-video',
        body: {'id': videoId},
      );

      print(
        'delete-video success response (status ${response.status}): ${response.data}',
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        print(
          'delete-video returned success=false (status ${response.status}): $data',
        );
        return {
          'success': false,
          'status': response.status,
          'data': data,
          'error':
              data['error']?.toString() ??
              data['message']?.toString() ??
              'Function returned success=false',
        };
      }

      return {'success': true, 'status': response.status, 'data': data};
    } on FunctionException catch (e) {
      print(
        'delete-video error response (status ${e.status}, reason: ${e.reasonPhrase}): ${e.details}',
      );
      return {
        'success': false,
        'status': e.status,
        'data': e.details,
        'error': e.details?.toString() ?? e.reasonPhrase ?? 'Function failed',
      };
    } catch (e) {
      print('delete-video unexpected error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete the current user's account via a Supabase Edge Function.
  ///
  /// This is the client-side caller only. The actual deletion logic lives in
  /// the Supabase Edge Function and should remove user-owned database rows,
  /// storage assets, and the auth user server-side.
  ///
  /// Parameters:
  /// - [functionName]: Deployed edge function name. Defaults to 'delet-all-data'.
  ///
  /// Returns:
  /// - {success: true, status, data} on success
  /// - {success: false, error, status?} on failure
  Future<Map<String, dynamic>> deleteCurrentUserViaEdgeFunction({
    String functionName = 'delet-all-data',
  }) async {
    try {
      final response = await _invokeAuthenticatedEdgeFunction(
        functionName,
        body: <String, dynamic>{},
      );

      print(
        '$functionName success response (status ${response.status}): ${response.data}',
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        print(
          '$functionName returned success=false (status ${response.status}): $data',
        );
        return {
          'success': false,
          'status': response.status,
          'data': data,
          'error':
              data['error']?.toString() ??
              data['message']?.toString() ??
              'Function returned success=false',
        };
      }

      return {'success': true, 'status': response.status, 'data': data};
    } on FunctionException catch (e) {
      print(
        '$functionName error response (status ${e.status}, reason: ${e.reasonPhrase}): ${e.details}',
      );
      return {
        'success': false,
        'status': e.status,
        'data': e.details,
        'error': e.details?.toString() ?? e.reasonPhrase ?? 'Function failed',
      };
    } catch (e) {
      print('$functionName unexpected error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<FunctionResponse> _invokeAuthenticatedEdgeFunction(
    String functionName, {
    Object? body,
  }) async {
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session == null || user == null) {
      print('$functionName aborted: user not authenticated');
      throw Exception('User not authenticated');
    }

    print(
      '$functionName auth context: userId=${user.id}, hasAccessToken=${session.accessToken.isNotEmpty}',
    );

    return client.functions.invoke(functionName, body: body);
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
          throw Exception(
            'Failed to delete $resourceName after $maxAttempts attempts: $e',
          );
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
  /// Automatically uses the authenticated user's ID from the auth context.
  /// Structured to support thousands of user profiles with proper indexing by user_id.
  ///
  /// Validates that:
  /// - Username is not empty
  /// - Username is no more than 20 characters
  /// - Username is not already taken before saving.
  ///
  /// Parameters:
  /// - [username]: The username to save for the authenticated user
  ///
  /// Returns: {success: true, message} on success or {success: false, error} on failure
  Future<Map<String, dynamic>> saveUserPersonalProfile(String username) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Validate username length
      if (username.length > 20) {
        return {'success': false, 'error': 'Keep it short! Max 20 characters.'};
      }

      // Check if username already exists (excluding current user's ID)
      final usernameTaken = await usernameExists(username, excludeId: userId);
      if (usernameTaken) {
        return {
          'success': false,
          'error': 'That username is taken! Try another one.',
        };
      }

      // Try to upsert - update if exists, insert if doesn't
      await client.from('user_personal_profiles').upsert({
        'id': userId,
        'username': username,
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

      final profile = await _buildUserPersonalProfile(data);

      print('✓ User personal profile fetched successfully');
      return profile;
    } catch (e) {
      print('Error fetching user personal profile: $e');
      return null;
    }
  }

  /// Fetch a particular user's public profile information.
  ///
  /// Returns null if the profile does not exist or an error occurs.
  Future<UserPersonalProfile?> fetchUserPersonalProfileById(
    String userId,
  ) async {
    try {
      return await _fetchUserPersonalProfileById(userId);
    } catch (e) {
      print('Error fetching profile for userId=$userId: $e');
      return null;
    }
  }

  /// Search public user profiles by username.
  ///
  /// Performs a case-insensitive search against the username field and returns
  /// lightweight profile summaries for UI search results.
  ///
  /// When [startsWithOnly] is true, only usernames beginning with [query]
  /// are returned. Otherwise, usernames containing [query] anywhere are
  /// returned, with prefix matches paginated ahead of looser contains matches.
  ///
  /// Returns:
  /// - `users`: current page of results
  /// - `totalCount`: total matches across all pages
  /// - `hasMore`: whether another page exists
  /// - `nextOffset`: offset to use for the next page
  Future<Map<String, dynamic>> searchUsersByUsername(
    String query, {
    int limit = 20,
    int offset = 0,
    bool startsWithOnly = false,
    bool excludeCurrentUser = true,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedLimit = limit <= 0 ? 20 : limit;
    final normalizedOffset = offset < 0 ? 0 : offset;

    if (normalizedQuery.isEmpty) {
      return {
        'users': <UserProfileSummary>[],
        'totalCount': 0,
        'hasMore': false,
        'nextOffset': normalizedOffset,
      };
    }

    try {
      final currentUserId = excludeCurrentUser ? getCurrentUserId() : null;
      final prefixPattern = '$normalizedQuery%';

      if (startsWithOnly) {
        final totalCount = await _countUserSearchMatches(
          pattern: prefixPattern,
          currentUserId: currentUserId,
        );

        if (normalizedOffset >= totalCount) {
          return {
            'users': <UserProfileSummary>[],
            'totalCount': totalCount,
            'hasMore': false,
            'nextOffset': normalizedOffset,
          };
        }

        final users = await _fetchUserSearchMatches(
          pattern: prefixPattern,
          currentUserId: currentUserId,
          limit: normalizedLimit,
          offset: normalizedOffset,
        );

        return {
          'users': users,
          'totalCount': totalCount,
          'hasMore': normalizedOffset + users.length < totalCount,
          'nextOffset': normalizedOffset + users.length,
        };
      }

      final containsPattern = '%$normalizedQuery%';
      final prefixCount = await _countUserSearchMatches(
        pattern: prefixPattern,
        currentUserId: currentUserId,
      );
      final containsNonPrefixCount = await _countUserSearchMatches(
        pattern: containsPattern,
        currentUserId: currentUserId,
        excludedPattern: prefixPattern,
      );
      final totalCount = prefixCount + containsNonPrefixCount;

      if (normalizedOffset >= totalCount) {
        return {
          'users': <UserProfileSummary>[],
          'totalCount': totalCount,
          'hasMore': false,
          'nextOffset': normalizedOffset,
        };
      }

      final users = <UserProfileSummary>[];

      if (normalizedOffset < prefixCount) {
        final prefixUsers = await _fetchUserSearchMatches(
          pattern: prefixPattern,
          currentUserId: currentUserId,
          limit: normalizedLimit,
          offset: normalizedOffset,
        );
        users.addAll(prefixUsers);

        final remainingSlots = normalizedLimit - users.length;
        if (remainingSlots > 0) {
          final containsUsers = await _fetchUserSearchMatches(
            pattern: containsPattern,
            currentUserId: currentUserId,
            limit: remainingSlots,
            offset: 0,
            excludedPattern: prefixPattern,
          );
          users.addAll(containsUsers);
        }
      } else {
        final containsOffset = normalizedOffset - prefixCount;
        final containsUsers = await _fetchUserSearchMatches(
          pattern: containsPattern,
          currentUserId: currentUserId,
          limit: normalizedLimit,
          offset: containsOffset,
          excludedPattern: prefixPattern,
        );
        users.addAll(containsUsers);
      }

      return {
        'users': users,
        'totalCount': totalCount,
        'hasMore': normalizedOffset + users.length < totalCount,
        'nextOffset': normalizedOffset + users.length,
      };
    } catch (e) {
      print('Error searching users by username: $e');
      return {
        'users': <UserProfileSummary>[],
        'totalCount': 0,
        'hasMore': false,
        'nextOffset': normalizedOffset,
      };
    }
  }

  Future<int> _countUserSearchMatches({
    required String pattern,
    String? currentUserId,
    String? excludedPattern,
  }) async {
    dynamic query = client
        .from('user_personal_profiles')
        .count(CountOption.exact)
        .ilike('username', pattern);

    if (currentUserId != null) {
      query = query.neq('id', currentUserId);
    }

    if (excludedPattern != null) {
      query = query.not('username', 'ilike', excludedPattern);
    }

    return await query as int;
  }

  Future<List<UserProfileSummary>> _fetchUserSearchMatches({
    required String pattern,
    required int limit,
    required int offset,
    String? currentUserId,
    String? excludedPattern,
  }) async {
    dynamic query = client
        .from('user_personal_profiles')
        .select('id, username, profileUrl, updated_at')
        .ilike('username', pattern);

    if (currentUserId != null) {
      query = query.neq('id', currentUserId);
    }

    if (excludedPattern != null) {
      query = query.not('username', 'ilike', excludedPattern);
    }

    query = query.order('username').range(offset, offset + limit - 1);

    final response = await query;

    return Future.wait(
      (response as List<dynamic>).whereType<Map<String, dynamic>>().map(
        _buildUserProfileSummary,
      ),
    );
  }

  /// Search public videos by title.
  ///
  /// Titles are stored initially in `my_videos` during upload, then copied into
  /// `sport_videos` when a user links a video into a public category. Search is
  /// performed by the `search_explore_videos` RPC so results match the public
  /// discovery/feed surfaces users can actually browse and can include creator
  /// username matches.
  ///
  /// Returns:
  /// - `videos`: current page of results
  /// - `totalCount`: total matches across all pages
  /// - `hasMore`: whether another page exists
  /// - `nextOffset`: offset to use for the next page
  Future<Map<String, dynamic>> searchVideosByTitle(
    String query, {
    int limit = 20,
    int offset = 0,
    String? sportId,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedLimit = limit <= 0 ? 20 : limit;
    final normalizedOffset = offset < 0 ? 0 : offset;
    final normalizedSportId = sportId?.trim();
    final hasSportFilter =
        normalizedSportId != null && normalizedSportId.isNotEmpty;

    if (normalizedQuery.isEmpty && !hasSportFilter) {
      return {
        'videos': <SportVideo>[],
        'totalCount': 0,
        'hasMore': false,
        'nextOffset': normalizedOffset,
      };
    }

    try {
      final response = await client.rpc(
        'search_explore_videos',
        params: {
          'p_query': normalizedQuery,
          'p_sport_id': hasSportFilter ? normalizedSportId : null,
          'p_limit': normalizedLimit,
          'p_offset': normalizedOffset,
        },
      );

      final rows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      final totalCount = rows.isEmpty
          ? 0
          : (rows.first['total_count'] as num?)?.toInt() ?? 0;
      final videos = await _buildSportVideosFromRows(rows);

      return {
        'videos': videos,
        'totalCount': totalCount,
        'hasMore': normalizedOffset + videos.length < totalCount,
        'nextOffset': normalizedOffset + videos.length,
      };
    } catch (e) {
      print('Error searching videos by title: $e');
      return {
        'videos': <SportVideo>[],
        'totalCount': 0,
        'hasMore': false,
        'nextOffset': normalizedOffset,
      };
    }
  }

  // /// Upload user profile image to Supabase storage and update database
  // ///
  // /// Validates that the file is a valid image format (JPEG, PNG, or WebP)
  // /// Uploads to the 'profile_images' bucket and updates the user_personal_profiles table
  // /// with the image URL path.
  // ///
  // /// Parameters:
  // /// - [imageFile]: The image file to upload (must be JPEG, PNG, or WebP)
  // ///
  // /// Returns: {success: true, imageUrl, message} on success
  // /// Returns: {success: false, error} on failure
  // Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
  //   File? compressedImageFile;

  //   try {
  //     final userId = getCurrentUserId();
  //     if (userId == null) {
  //       return {'success': false, 'error': 'User not authenticated'};
  //     }

  //     compressedImageFile = await _compressImageForUpload(
  //       imageFile,
  //       fileNamePrefix: 'profile_image',
  //       maxDimension: _profileImageMaxDimension,
  //       quality: _profileImageQuality,
  //     );
  //     print(
  //       '$_debugMediaPrefix Uploading profile image to Supabase: ${compressedImageFile.path} (${_formatBytes(await compressedImageFile.length())})',
  //     );

  //     // Get file extension
  //     final extension = _getFileExtension(compressedImageFile.path);
  //     final path = '$userId/profile_image.$extension';

  //     // Upload file to storage
  //     await _uploadService.uploadFile(
  //       file: compressedImageFile,
  //       bucketName: 'profile_images',
  //       path: path,
  //     );

  //     // Generate public URL with cache-busting parameter
  //     var imageUrl = client.storage.from('profile_images').getPublicUrl(path);
  //     final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     imageUrl = '$imageUrl?t=$timestamp';

  //     // Update user profile with image URL in database
  //     await client.from('user_personal_profiles').upsert({
  //       'id': userId,
  //       'profileUrl': imageUrl,
  //       'updated_at': DateTime.now().toIso8601String(),
  //     }, onConflict: 'id');

  //     return {
  //       'success': true,
  //       'imageUrl': imageUrl,
  //       'message': 'Profile image uploaded successfully! 🎉',
  //     };
  //   } catch (e) {
  //     print('Error uploading profile image: $e');
  //     return {'success': false, 'error': e.toString()};
  //   } finally {
  //     await _deleteTemporaryCompressedFile(compressedImageFile, imageFile);
  //   }
  // }

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
    File? compressedImageFile;

    try {
      // ==================== STEP 1: Upload Image to Storage ====================
      compressedImageFile = await _compressImageForUpload(
        imageFile,
        fileNamePrefix: 'profile_image',
        maxDimension: _profileImageMaxDimension,
        quality: _profileImageQuality,
      );
      print(
        '$_debugMediaPrefix Uploading profile image to Supabase: ${compressedImageFile.path} (${_formatBytes(await compressedImageFile.length())})',
      );

      final extension = _getFileExtension(compressedImageFile.path);
      final path = '$userId/profile_image.$extension';
      final mimeType = lookupMimeType(compressedImageFile.path) ?? 'image/jpeg';

      // Upload directly with the Supabase Storage client.
      // Profile images reuse a stable path, so enable upsert to overwrite.
      print(
        '$_debugMediaPrefix Starting profile image storage upload: bucket=profile_images, path=$path, mimeType=$mimeType, file=${compressedImageFile.path}',
      );
      try {
        await client.storage
            .from('profile_images')
            .upload(
              path,
              compressedImageFile,
              fileOptions: FileOptions(upsert: true, contentType: mimeType),
            );
        print(
          '$_debugMediaPrefix Profile image storage upload succeeded: bucket=profile_images, path=$path',
        );
      } catch (uploadError) {
        print(
          '$_debugMediaPrefix Profile image storage upload failed: bucket=profile_images, path=$path, mimeType=$mimeType, error=$uploadError',
        );
        rethrow;
      }

      uploadedImagePath = path;

      final updatedAt = DateTime.now().toIso8601String();

      // ==================== STEP 2: Generate Public URL ====================
      final imageUrl = await _resolveProfileImageUrl(
        path,
        updatedAt: updatedAt,
      );

      // ==================== STEP 3: Save URL to Database ====================
      // Persist the storage path only, not the generated URL.
      // This keeps the database stable if the public URL format, bucket access
      // strategy, or cache-busting approach changes later.
      final updateData = {
        'id': userId,
        'username': username,
        'profileUrl': path,
        'updated_at': updatedAt,
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
    } finally {
      await _deleteTemporaryCompressedFile(compressedImageFile, imageFile);
    }
  }

  // ==================== UTILITY OPERATIONS ====================
  /// Fetch all videos for the current user from my_videos table
  ///
  /// Retrieves all video records from the database for the authenticated user.
  /// Returns strongly-typed MyVideo models for display in the UI.
  ///
  /// Returns a list of MyVideo models containing all video metadata including:
  /// - id, createdAt, userId, title, videoPath, thumbnailPath, thumbnailUrl
  /// - viewCount, averageRating, likeCount, subcategoryId, sportId, subcategoryName, approved
  ///
  /// Returns empty list if user not authenticated or no videos found.
  /// Throws exception on database query errors.
  Future<List<MyVideo>> getMyVideo() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return [];
      }

      final videos = await client
          .from('my_videos')
          .select(
            'id, created_at, user_id, title, video_path, thumbnail_path, view_count, average_rating, like_count, subcategory_id, sport_id, subcategory_name, approved',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Convert storage paths to URLs
      final videosAsJson = (videos as List<dynamic>)
          .map((v) => v as Map<String, dynamic>)
          .toList();

      final videosWithUrls = await Future.wait(
        videosAsJson.map(_convertVideoPathsToUrls),
      );

      final myVideos = <MyVideo>[];
      for (final video in videosWithUrls) {
        final myVideo = MyVideo.fromJson(video);
        myVideos.add(myVideo);
      }
      return myVideos;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all uploaded videos for a specific user.
  ///
  /// Uses the same data shape as the current user's profile video list so it can
  /// be rendered consistently in profile-style UIs.
  Future<List<MyVideo>> getVideosForUserById(String userId) async {
    try {
      return await _getVideosForUserId(userId);
    } catch (e) {
      print('Error fetching uploaded videos for userId=$userId: $e');
      return [];
    }
  }

  /// Submit a video report for moderation
  ///
  /// Records the current user's report of a video (e.g., harassment, inappropriate content).
  /// The report is stored in the database and can be reviewed by moderators.
  /// The current authenticated user is automatically recorded as the reporter.
  ///
  /// Parameters:
  /// - [videoId]: The UUID of the video being reported
  /// - [reason]: The report reason/category (e.g., 'harassment', 'hateSpeech', etc.)
  ///
  /// Returns: {success: true, reportId, message} on success
  /// Returns: {success: false, error} on failure
  Future<Map<String, dynamic>> submitVideoReport({
    required String videoId,
    required String reason,
  }) async {
    try {
      // Get current authenticated user
      final reportedBy = getCurrentUserId();
      if (reportedBy == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Validate inputs
      if (videoId.trim().isEmpty) {
        return {'success': false, 'error': 'Video ID cannot be empty'};
      }
      if (reason.trim().isEmpty) {
        return {'success': false, 'error': 'Report reason cannot be empty'};
      }

      print(
        '[VIDEO_REPORT] Submitting report - videoId=$videoId, reason=$reason, reportedBy=$reportedBy',
      );

      // Insert report into database
      final response = await client.from('video_reports').insert({
        'video_id': videoId,
        'reason': reason,
        'reported_by': reportedBy,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending', // Reports start in pending status for review
      }).select();

      if (response.isEmpty) {
        throw Exception('Database insert failed: empty response');
      }

      final reportId = response[0]['id'] as String?;
      if (reportId == null || reportId.isEmpty) {
        throw Exception('Database insert failed: missing report ID');
      }

      print('✓ Video report submitted successfully - reportId=$reportId');
      return {
        'success': true,
        'reportId': reportId,
        'message': 'Thank you for your report. We will review it shortly.',
      };
    } catch (e) {
      print('Error submitting video report: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch a user's public profile info together with all uploaded videos.
  ///
  /// Visibility rules:
  /// - When the current user is viewing their own profile, videos come from
  ///   `my_videos`, which is the owner's personal upload collection.
  /// - When viewing someone else's profile, videos come from `sport_videos`,
  ///   which is the public/discovery-facing dataset used by feed surfaces.
  ///
  /// This split is intentional. Feed screens navigate to creator profiles from
  /// public `sport_videos` records, so reading another user's profile from
  /// `my_videos` can return an empty list even when that user has public videos
  /// visible elsewhere in the app.
  ///
  /// Egress behavior:
  /// - This method fetches database rows plus thumbnail URLs for grid display.
  /// - It does not download video bytes up front.
  /// - Video playback remains lazy and only resolves the storage path into a
  ///   signed/public URL when the user opens a specific video.
  ///
  /// Pagination behavior:
  /// - Only one page of videos is fetched per call.
  /// - Use [limit] and [offset] to load profile grids incrementally.
  /// - `totalVideoCount` reports the creator's full video count from the same
  ///   backing source used for the current profile view.
  /// - `hasMoreVideos` is computed from `offset + loadedVideos < totalVideoCount`
  ///   so the UI can decide whether to request the next page.
  ///
  /// Returns:
  /// - {success: true, profile, videos, totalVideoCount, hasMoreVideos} on success
  /// - {success: false, error} on failure
  Future<Map<String, dynamic>> fetchUserProfileWithUploadedVideos(
    String userId, [
    int limit = 20,
    int offset = 0,
  ]) async {
    try {
      final profile = await _fetchUserPersonalProfileById(userId);
      if (profile == null) {
        return {'success': false, 'error': 'User profile not found'};
      }

      final currentUserId = getCurrentUserId();
      final isOwnProfile = currentUserId == userId;
      // Use the owner's private upload collection only for self-profile views.
      // For other users, load the public linked/discovery videos so creator
      // profiles match what users can already see in home/discovery feeds.
      final totalVideoCount = isOwnProfile
          ? await _getVideoCountForUserId(userId)
          : await _getPublicVideoCountForUserId(userId);
      if (totalVideoCount == 0 || offset >= totalVideoCount) {
        return {
          'success': true,
          'profile': profile,
          'videos': const <MyVideo>[],
          'totalVideoCount': totalVideoCount,
          'hasMoreVideos': false,
        };
      }

      final videos = isOwnProfile
          ? await _getVideosForUserId(userId, limit, offset)
          : await _getPublicVideosForUserId(userId, limit, offset);

      return {
        'success': true,
        'profile': profile,
        'videos': videos,
        'totalVideoCount': totalVideoCount,
        'hasMoreVideos': offset + videos.length < totalVideoCount,
      };
    } catch (e) {
      print('Error fetching profile with videos for userId=$userId: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<UserPersonalProfile?> _fetchUserPersonalProfileById(
    String userId,
  ) async {
    final data = await client
        .from('user_personal_profiles')
        .select('id, username, profileUrl, updated_at')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return _buildUserPersonalProfile(data);
  }

  Future<List<MyVideo>> _getVideosForUserId(
    String userId, [
    int? limit,
    int offset = 0,
  ]) async {
    // Private/self profile source: query the owner's personal upload table.
    final videos = limit == null
        ? await client
              .from('my_videos')
              .select(
                'id, created_at, user_id, title, video_path, thumbnail_path, view_count, average_rating, like_count, subcategory_id, sport_id, subcategory_name, approved',
              )
              .eq('user_id', userId)
              .order('created_at', ascending: false)
        : await client
              .from('my_videos')
              .select(
                'id, created_at, user_id, title, video_path, thumbnail_path, view_count, average_rating, like_count, subcategory_id, sport_id, subcategory_name, approved',
              )
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

    final rawVideos = (videos as List<dynamic>)
        .map((video) => video as Map<String, dynamic>)
        .toList();
    final videosWithUrls = await Future.wait(
      rawVideos.map(_convertVideoPathsToUrls),
    );

    final myVideos = <MyVideo>[];
    for (final video in videosWithUrls) {
      myVideos.add(MyVideo.fromJson(video));
    }

    return myVideos;
  }

  Future<List<MyVideo>> _getPublicVideosForUserId(
    String userId, [
    int? limit,
    int offset = 0,
  ]) async {
    // Public/other profile source: query the discovery table that powers feeds.
    // These rows represent videos the user has linked publicly to a sport or
    // category, so they are safe to show on another user's creator profile.
    final videos = limit == null
        ? await client
              .from('sport_videos')
              .select(
                'id, created_at, user_id, title, video_path, thumbnail_path, view_count, average_rating, bayesian_score, subcategory_id, sport_id',
              )
              .eq('user_id', userId)
              .order('created_at', ascending: false)
        : await client
              .from('sport_videos')
              .select(
                'id, created_at, user_id, title, video_path, thumbnail_path, view_count, average_rating, bayesian_score, subcategory_id, sport_id',
              )
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

    final rawVideos = (videos as List<dynamic>)
        .map((video) => video as Map<String, dynamic>)
        .toList();
    final videosWithUrls = await Future.wait(
      rawVideos.map(_convertVideoPathsToUrls),
    );

    final myVideos = <MyVideo>[];
    for (final video in videosWithUrls) {
      myVideos.add(MyVideo.fromJson(video));
    }

    return myVideos;
  }

  Future<int> _getVideoCountForUserId(String userId) async {
    return client
        .from('my_videos')
        .count(CountOption.exact)
        .eq('user_id', userId);
  }

  Future<int> _getPublicVideoCountForUserId(String userId) async {
    return client
        .from('sport_videos')
        .count(CountOption.exact)
        .eq('user_id', userId);
  }

  Future<UserPersonalProfile> _buildUserPersonalProfile(
    Map<String, dynamic> data,
  ) async {
    // Profile rows store only the storage path. Resolve it here so the rest of
    // the app can continue treating profileUrl as a display-ready network URL.
    return UserPersonalProfile(
      id: data['id'] as String?,
      username: data['username'] as String,
      profileUrl: await _resolveProfileImageUrl(
        data['profileUrl'] as String?,
        updatedAt: data['updated_at'] as String?,
      ),
    );
  }

  Future<UserProfileSummary> _buildUserProfileSummary(
    Map<String, dynamic> data,
  ) async {
    return UserProfileSummary(
      id: data['id'] as String,
      username: data['username'] as String? ?? 'Unknown User',
      profileUrl: await _resolveProfileImageUrl(
        data['profileUrl'] as String?,
        updatedAt: data['updated_at'] as String?,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _normalizeUserProfileMaps(
    List<Map<String, dynamic>> profiles,
  ) {
    // Follower/following queries return raw maps instead of model objects, so
    // normalize profile image paths into network URLs before the UI consumes them.
    return Future.wait(
      profiles.map((profile) async {
        final normalizedProfile = Map<String, dynamic>.from(profile);
        normalizedProfile['profileUrl'] = await _resolveProfileImageUrl(
          normalizedProfile['profileUrl'] as String?,
          updatedAt: normalizedProfile['updated_at'] as String?,
        );
        return normalizedProfile;
      }),
    );
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
        'Could not create signed URL for $bucketName/$path, using public URL. Error: $e',
      );
      return client.storage.from(bucketName).getPublicUrl(path);
    }
  }

  Future<String?> _resolveProfileImageUrl(
    String? storedValue, {
    String? updatedAt,
  }) async {
    if (storedValue == null || storedValue.isEmpty) {
      return storedValue;
    }

    final imageUrl = await _pathToUrl('profile_images', storedValue);
    final cacheBustingValue = _profileImageCacheBustingValue(updatedAt);
    if (cacheBustingValue == null || cacheBustingValue.isEmpty) {
      return imageUrl;
    }

    final separator = imageUrl.contains('?') ? '&' : '?';
    return '$imageUrl${separator}t=$cacheBustingValue';
  }

  // Reuse updated_at as a deterministic cache-busting token so clients fetch
  // the new bytes after a profile image overwrite without storing URLs in the DB.
  String? _profileImageCacheBustingValue(String? updatedAt) {
    if (updatedAt == null || updatedAt.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(updatedAt).millisecondsSinceEpoch.toString();
    } catch (_) {
      return Uri.encodeQueryComponent(updatedAt);
    }
  }

  /// Resolve a stored video path into a playable URL when needed.
  Future<String> resolveVideoPlaybackUrl(String videoPathOrUrl) async {
    final isNetworkUrl =
        videoPathOrUrl.startsWith('http://') ||
        videoPathOrUrl.startsWith('https://');

    if (isNetworkUrl) {
      return videoPathOrUrl;
    }

    return _pathToUrl('my_videos', videoPathOrUrl);
  }

  Future<File> _compressImageForUpload(
    File sourceFile, {
    required String fileNamePrefix,
    required int maxDimension,
    required int quality,
  }) async {
    final mimeType = lookupMimeType(sourceFile.path) ?? '';
    if (!mimeType.startsWith('image/')) {
      return sourceFile;
    }

    final originalBytes = await sourceFile.length();
    print(
      '$_debugMediaPrefix Compressing image "$fileNamePrefix": original size ${_formatBytes(originalBytes)}, maxDimension=$maxDimension, quality=$quality',
    );

    final tempDir = await getTemporaryDirectory();
    final compressedPath = p.join(
      tempDir.path,
      '${fileNamePrefix}_${const Uuid().v4()}.jpg',
    );

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      sourceFile.absolute.path,
      compressedPath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (compressedFile == null) {
      print(
        '$_debugMediaPrefix Image compression returned null, using original file instead.',
      );
      return sourceFile;
    }

    final compressedFileAsFile = File(compressedFile.path);
    final compressedBytes = await compressedFileAsFile.length();
    final savingsPercent = originalBytes == 0
        ? 0.0
        : (1 - (compressedBytes / originalBytes)) * 100;
    print(
      '$_debugMediaPrefix Compressed image "$fileNamePrefix": ${_formatBytes(originalBytes)} -> ${_formatBytes(compressedBytes)} (${savingsPercent.toStringAsFixed(1)}% smaller)',
    );

    return compressedFileAsFile;
  }

  Future<File> _compressVideoForUpload(
    File sourceFile, {
    required VideoQuality quality,
  }) async {
    final mimeType = lookupMimeType(sourceFile.path) ?? '';
    if (!mimeType.startsWith('video/')) {
      return sourceFile;
    }

    final originalBytes = await sourceFile.length();
    print(
      '$_debugMediaPrefix Compressing video: original size ${_formatBytes(originalBytes)}, quality=${quality.name}',
    );

    final mediaInfo = await VideoCompress.compressVideo(
      sourceFile.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );

    final compressedFile = mediaInfo?.file;
    if (compressedFile == null) {
      print(
        '$_debugMediaPrefix Video compression returned null, using original file instead.',
      );
      return sourceFile;
    }

    final compressedBytes = await compressedFile.length();
    final savingsPercent = originalBytes == 0
        ? 0.0
        : (1 - (compressedBytes / originalBytes)) * 100;
    print(
      '$_debugMediaPrefix Compressed video: ${_formatBytes(originalBytes)} -> ${_formatBytes(compressedBytes)} (${savingsPercent.toStringAsFixed(1)}% smaller)',
    );
    print(
      '$_debugMediaPrefix Uploading video file to Supabase: ${compressedFile.path} (${_formatBytes(compressedBytes)})',
    );

    return compressedFile;
  }

  Future<void> _deleteTemporaryCompressedFile(
    File? candidate,
    File original,
  ) async {
    if (candidate == null || candidate.path == original.path) {
      return;
    }

    if (await candidate.exists()) {
      await candidate.delete();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1000 * 1000) {
      return '${(bytes / (1000 * 1000)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1000) {
      return '${(bytes / 1000).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _toPostgrestInList(Iterable<Object> values) {
    return '(${values.map((value) {
      if (value is num || value is bool) {
        return value.toString();
      }

      final escapedValue = value.toString().replaceAll('"', r'\"');
      return '"$escapedValue"';
    }).join(',')})';
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
  Future<Map<String, List<SportSubcategory>>>
  getAllSportsWithSubcategories() async {
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
          .select(
            'id, created_at, user_id, title, description, video_path, thumbnail_path',
          )
          .eq('id', videoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (videoData == null) {
        return {
          'success': false,
          'error': 'Video not found or does not belong to you',
        };
      }

      final sourceVideo = MyVideo.fromJson(videoData);

      // STEP 2: Check if video is already linked to a subcategory
      final existingLink = await client
          .from('sport_videos')
          .select('id')
          .eq('user_video_id', videoId)
          .maybeSingle();

      if (existingLink != null) {
        return {
          'success': false,
          'error':
              'You\'ve already linked this video to a category. Each video can only belong to one category.',
        };
      }

      // STEP 3: Link video to subcategory with denormalized data
      // This allows efficient discovery queries without JOINs
      // Note: videoData contains paths from my_videos table (URLs generated on-demand)
      final insertResponse = await client.from('sport_videos').insert({
        'user_id': userId,
        'user_video_id': videoId,
        'sport_id': sportId,
        'subcategory_id': subcategoryId,
        'title': sourceVideo.title,
        'description': sourceVideo.description ?? '',
        'video_path': sourceVideo.videoPath,
        'thumbnail_path': sourceVideo.thumbnailPath,
        'view_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select();

      if (insertResponse.isEmpty) {
        return {'success': false, 'error': 'Failed to link video to category'};
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
  /// Each video contains: {id, title, description, video_path, thumbnail_path, thumbnailUrl, view_count, username, created_at}
  Future<List<SportVideo>> getSportCategoryVideos({
    required String sportId,
    required String subcategoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final videos = await client
          .from('sport_videos')
          .select(
            'id, user_id, user_video_id, sport_id, title, description, video_path, thumbnail_path, view_count, created_at, bayesian_score, total_ratings, average_rating, user_personal_profiles(username)',
          )
          .eq('sport_id', sportId)
          .eq('subcategory_id', subcategoryId)
          .order('bayesian_score', ascending: false)
          .order('total_ratings', ascending: false)
          .range(offset, offset + limit - 1);

      // This query already includes the nested username, so the shared row
      // builder can produce fully populated SportVideo models directly.
      final sportVideos = await _buildSportVideosFromRows(
        videos,
      );

      print(
        '✓ Fetched ${sportVideos.length} videos for $sportId/$subcategoryId',
      );
      return sportVideos;
    } catch (e) {
      print('Error fetching category videos: $e');
      return <SportVideo>[];
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
  /// Returns: List of linked public videos as [SportVideo] models
  Future<List<SportVideo>> getUserLinkedVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return <SportVideo>[];
      }

      final videos = await client
          .from('sport_videos')
          .select(
            'id, user_id, user_video_id, sport_id, title, description, video_path, thumbnail_path, view_count, created_at, total_ratings, average_rating, bayesian_score',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('✓ Fetched ${videos.length} linked videos for user $userId');
      // Linked-video rows do not include username because this surface does not
      // currently render creator attribution.
      return _buildSportVideosFromRows(videos as List<dynamic>);
    } catch (e) {
      print('Error fetching user linked videos: $e');
      return <SportVideo>[];
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
  ///
  /// Returns: {success: true} or {success: false, error}
  ///
  /// Note: This calls the increment-video-views Edge Function, which
  /// triggers the protected increment_both_view_counts() PostgreSQL function.
  /// Safe for concurrent views - no race conditions, no lost counts.
  Future<Map<String, dynamic>> updateCategoryVideoViewCount({
    required String linkedVideoId,
  }) async {
    try {
      final response = await _invokeAuthenticatedEdgeFunction(
        'increment-video-views',
        body: {'linked_video_id': linkedVideoId},
      );

      final data = response.data as Map<String, dynamic>?;

      if (data != null && data['error'] != null) {
        print(
          '❌ View count increment failed for $linkedVideoId: ${data['error']}',
        );
      }

      return {'success': true};
    } catch (e) {
      print('❌ Error updating view count for $linkedVideoId: $e');
      return {'success': true};
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
  /// - [videoId]: UUID of the my_videos table record
  /// - [rating]: Rating value (must be 1-10 inclusive)
  ///
  /// Returns:
  /// - {success: true} - Rating submitted/updated successfully
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
        return {'success': false, 'error': 'Rating must be between 1 and 10'};
      }

      // Upsert: inserts new rating if user hasn't rated, updates if they have.
      // The live schema stores ratings against my_videos.id via video_id.
      await client.from('video_ratings').upsert({
        'user_id': userId,
        'video_id': videoId,
        'rating': rating,
      }, onConflict: 'video_id,user_id');

      return {'success': true};
    } on PostgrestException catch (e) {
      print('[RATE_VIDEO] PostgrestException caught');
      print('[RATE_VIDEO] Error code: ${e.code}');
      print('[RATE_VIDEO] Error message: ${e.message}');
      print('[RATE_VIDEO] Error details: ${e.details}');
      print('[RATE_VIDEO] Full error: $e');

      return {'success': false, 'error': e.message};
    } catch (e) {
      print('[RATE_VIDEO] General exception caught');
      print('[RATE_VIDEO] Error type: ${e.runtimeType}');
      print('[RATE_VIDEO] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get the current user's rating for a video (if they've rated it)
  ///
  /// Checks if the current user has already rated a specific video.
  /// Used to display which rating button should be highlighted in the UI.
  ///
  /// Parameters:
  /// - [videoId]: UUID of the my_videos table record
  ///
  /// Returns:
  /// - VideoRating - The user's saved rating row
  /// - null - User is unauthenticated, has not rated the video, or lookup failed
  Future<VideoRating?> getUserRating({required String videoId}) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return null;
      }

      // Query video_ratings for this user's vote on the original my_videos row.
      // maybeSingle() returns null if no rating exists (graceful, no error)
      final result = await client
          .from('video_ratings')
          .select('video_id, user_id, rating, created_at, updated_at')
          .eq('video_id', videoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null) {
        return null;
      }

      return VideoRating.fromJson(result);
    } catch (e) {
      print('Error getting user rating: $e');
      return null;
    }
  }

  /// Delete the current user's rating for a video
  ///
  /// Removes the user's rating from the video_ratings table.
  /// The PostgreSQL trigger automatically recalculates the linked
  /// sport_videos row by matching sport_videos.user_video_id to this my_videos id.
  ///
  /// Parameters:
  /// - [videoId]: UUID of the my_videos table record
  ///
  /// Returns:
  /// - {success: true} - Rating deleted successfully
  /// - {success: false, error} - Error occurred or user not authenticated
  Future<Map<String, dynamic>> deleteRating({required String videoId}) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Delete the user's rating from video_ratings table
      await client
          .from('video_ratings')
          .delete()
          .eq('video_id', videoId)
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

  /// Block a user.
  ///
  /// Creates a row in `user_blocks` so backend RLS can hide the blocked
  /// relationship everywhere else in the app. The database trigger is
  /// responsible for cleaning up any existing follow rows.
  ///
  /// Parameters:
  /// - [userIdToBlock]: UUID of the user to block
  ///
  /// Returns:
  /// - [UserBlock] - Successfully blocked user
  ///
  /// Throws:
  /// - [Exception] when validation fails or the database request fails
  Future<UserBlock> blockUser({
    required String userIdToBlock,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (userId == userIdToBlock) {
      throw Exception('You cannot block yourself');
    }

    try {
      final response = await client
          .from('user_blocks')
          .insert({
            'blocker_id': userId,
            'blocked_id': userIdToBlock,
          })
          .select('id, blocker_id, blocked_id, created_at')
          .single();

      print('✓ Successfully blocked user $userIdToBlock');
      return UserBlock.fromJson(response);
    } on PostgrestException catch (e) {
      print('Error blocking user: $e');

      if (e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique')) {
        throw Exception('This user is already blocked');
      }

      throw Exception(e.message);
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user.
  ///
  /// Removes the directional block row from `user_blocks` so backend RLS can
  /// allow visibility again. This does not restore old follow relationships.
  ///
  /// Parameters:
  /// - [userIdToUnblock]: UUID of the user to unblock
  ///
  /// Throws:
  /// - [Exception] when validation fails or the database request fails
  Future<void> unblockUser({
    required UserBlock userBlock,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (userId == userBlock.blockedId) {
      throw Exception('You cannot unblock yourself');
    }

    try {
      await client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', userBlock.blockedId);

      print('✓ Successfully unblocked user ${userBlock.blockedId}');
    } on PostgrestException catch (e) {
      print('Error unblocking user: $e');
      throw Exception(e.message);
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Get all users that the current user has blocked.
  ///
  /// Retrieves a paginated list of users blocked by the current user and
  /// returns lightweight typed profile summaries.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of users to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of blocked user rows with flattened blocked-user display data
  Future<List<UserBlock>> getBlockedUsers({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      final blocks = await client
          .from('user_blocks')
          .select('id, blocker_id, blocked_id, created_at')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (blocks.isEmpty) {
        return [];
      }

      final typedBlocks = (blocks as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(UserBlock.fromJson)
          .toList(growable: false);

      final blockedUserIds = List<String>.from(
        typedBlocks.map((block) => block.blockedId),
      );

      final profiles = await client
          .from('user_personal_profiles')
          .select('id, username, profileUrl, updated_at')
          .inFilter('id', blockedUserIds);

      final normalizedProfiles = await _normalizeUserProfileMaps(
        List<Map<String, dynamic>>.from(profiles as List<dynamic>),
      );
      final profilesById = <String, UserProfileSummary>{
        for (final profile in normalizedProfiles)
          profile['id'] as String: UserProfileSummary.fromMap(profile),
      };

      final blockedUsers = typedBlocks
          .map((block) {
            final profile = profilesById[block.blockedId];
            if (profile == null) {
              return block;
            }

            return block.copyWith(
              blockedUsername: profile.username,
              blockedProfileUrl: profile.profileUrl,
            );
          })
          .toList(growable: false);

      if (profilesById.length != blockedUserIds.length) {
        final missingProfileIds = blockedUserIds
            .where((blockedUserId) => !profilesById.containsKey(blockedUserId))
            .toList(growable: false);
        print(
          '[BLOCKED_USERS] Missing profile rows for blocked user IDs: $missingProfileIds',
        );
      }

      print(
        '✓ Fetched ${blockedUsers.length} blocked users for current user (${profilesById.length} profiles resolved)',
      );

      return blockedUsers;
    } catch (e) {
      print('Error fetching blocked users: $e');
      return <UserBlock>[];
    }
  }

  /// Follow a user
  ///
  /// Creates a follow relationship where the current user follows another user.
  /// Stores user ID, timestamp, and uses database indexes for efficient queries.
  /// Prevents duplicate follows and self-follows through validation.
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

      // Insert follow relationship with timestamp
      // UNIQUE constraint prevents duplicates
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
        return {
          'success': false,
          'error': 'You\'re already following this user',
        };
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
  /// Efficiently queries the user_follows table with database indexes
  /// for fast lookups. Scales well to thousands of follows.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of users to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of typed user profile summaries
  Future<List<UserProfileSummary>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      // Query user_follows table with index on (follower_id)
      // Scales efficiently even with thousands of follows
      final follows = await client
          .from('user_follows')
          .select('followed_user_id')
          .eq('follower_id', userId)
          .range(offset, offset + limit - 1);

      if (follows.isEmpty) {
        return [];
      }

      // Extract user IDs from follow relationships
      final followedUserIds = List<String>.from(
        follows.map((f) => f['followed_user_id']),
      );

      // Fetch profile data for all followed users
      final profiles = await client
          .from('user_personal_profiles')
          .select('id, username, profileUrl, updated_at')
          .inFilter('id', followedUserIds);

      print(
        '✓ Fetched ${profiles.length} users that current user is following',
      );
      final normalizedProfiles = await _normalizeUserProfileMaps(
        List<Map<String, dynamic>>.from(profiles as List<dynamic>),
      );

      return normalizedProfiles
          .map(UserProfileSummary.fromMap)
          .toList(growable: false);
    } catch (e) {
      print('Error fetching following list: $e');
      return <UserProfileSummary>[];
    }
  }

  /// Get all followers of the current user
  ///
  /// Retrieves a paginated list of users that follow the current user.
  /// Includes user profile information (username, profile image).
  /// Uses database index on (followed_user_id) for efficient queries.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of users to return (default: 20)
  /// - [offset]: Pagination offset (default: 0)
  ///
  /// Returns: List of typed user profile summaries
  Future<List<UserProfileSummary>> getFollowers({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      // Query user_follows table with index on (followed_user_id)
      // This is O(k log n) where k = number of followers
      // Much faster than fetching all users and filtering client-side
      final follows = await client
          .from('user_follows')
          .select('follower_id')
          .eq('followed_user_id', userId)
          .range(offset, offset + limit - 1);

      if (follows.isEmpty) {
        return [];
      }

      // Extract follower user IDs
      final followerUserIds = List<String>.from(
        follows.map((f) => f['follower_id']),
      );

      // Fetch profile data for all followers
      final profiles = await client
          .from('user_personal_profiles')
          .select('id, username, profileUrl, updated_at')
          .inFilter('id', followerUserIds);

      print('✓ Fetched ${profiles.length} followers for current user');
      final normalizedProfiles = await _normalizeUserProfileMaps(
        List<Map<String, dynamic>>.from(profiles as List<dynamic>),
      );

      return normalizedProfiles
          .map(UserProfileSummary.fromMap)
          .toList(growable: false);
    } catch (e) {
      print('Error fetching followers list: $e');
      return <UserProfileSummary>[];
    }
  }

  /// Search within the current user's following list by username.
  Future<List<UserProfileSummary>> searchFollowingUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return getFollowing(limit: limit, offset: offset);
    }

    try {
      final response = await client.rpc(
        'search_my_following',
        params: {
          'p_query': normalizedQuery,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final normalizedProfiles = await _normalizeUserProfileMaps(
        List<Map<String, dynamic>>.from(response as List<dynamic>),
      );

      return normalizedProfiles
          .map(UserProfileSummary.fromMap)
          .toList(growable: false);
    } catch (e) {
      print('Error searching following users: $e');
      return <UserProfileSummary>[];
    }
  }

  /// Search within the current user's followers list by username.
  Future<List<UserProfileSummary>> searchFollowersUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return getFollowers(limit: limit, offset: offset);
    }

    try {
      final response = await client.rpc(
        'search_my_followers',
        params: {
          'p_query': normalizedQuery,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final normalizedProfiles = await _normalizeUserProfileMaps(
        List<Map<String, dynamic>>.from(response as List<dynamic>),
      );

      return normalizedProfiles
          .map(UserProfileSummary.fromMap)
          .toList(growable: false);
    } catch (e) {
      print('Error searching followers users: $e');
      return <UserProfileSummary>[];
    }
  }

  /// Get the count of users following the current user
  ///
  /// Returns the number of users who follow the current user.
  /// Uses efficient query on user_follows table with index.
  ///
  /// Returns:
  /// - {success: true, count: 42} - Follower count
  /// - {success: false, count: 0, error} - Error occurred
  Future<Map<String, dynamic>> getFollowerCount() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'count': 0,
          'error': 'User not authenticated',
        };
      }

      // Query user_follows table
      // Index on (followed_user_id) makes this efficient
      final follows = await client
          .from('user_follows')
          .select('id')
          .eq('followed_user_id', userId);

      final count = follows.length;

      print('✓ Fetched follower count: $count');
      return {'success': true, 'count': count};
    } catch (e) {
      print('Error fetching follower count: $e');
      return {'success': false, 'count': 0, 'error': e.toString()};
    }
  }

  /// Get the count of users the current user is following
  ///
  /// Returns the number of users the current user follows.
  /// Uses efficient query on user_follows table.
  ///
  /// Returns:
  /// - {success: true, count: 18} - Following count
  /// - {success: false, count: 0, error} - Error occurred
  Future<Map<String, dynamic>> getFollowingCount() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'count': 0,
          'error': 'User not authenticated',
        };
      }

      // Query user_follows table
      // Index on (follower_id) makes this efficient
      final follows = await client
          .from('user_follows')
          .select('id')
          .eq('follower_id', userId);

      final count = follows.length;

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
  /// Queries the user_follows table for this follow relationship.
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

      // Query user_follows table for this relationship
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
      return {'success': false, 'isFollowing': false, 'error': e.toString()};
    }
  }

  // ==================== URL GENERATION (Single Source of Truth) ====================

  /// Generate public URL from storage bucket and path
  ///
  /// This is the CENTRALIZED URL generation method - the single source of truth.
  /// Database stores only paths; URLs are generated on-demand by this method.
  ///
  /// This pattern follows industry best practices (Instagram, YouTube, etc.):
  /// - Flexible: Change CDN/bucket structure without database migration
  /// - Secure: Easy to implement signed URLs or expiration
  /// - Maintainable: Single point to update URL format
  /// - Scalable: Support multiple URL types (public, signed, with transforms)
  ///
  /// Parameters:
  /// - [bucketName]: Supabase storage bucket (e.g., 'my-thumbnails', 'my_videos')
  /// - [path]: Asset path from database (e.g., 'profiles/user123/videos/abc.png')
  ///
  /// Returns: Full public URL string (https://project.supabase.co/storage/...)
  String _generatePublicUrl(String bucketName, String path) {
    return client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Convert feed video object paths for list/grid consumption.
  ///
  /// Thumbnails are resolved immediately because the UI renders them in grids.
  /// The thumbnail bucket is public, so use its public URL directly.
  /// Video storage paths are preserved and resolved lazily only when playback
  /// starts.
  ///
  /// Parameters:
  /// - [video]: Video object from database with path fields
  ///
  /// Returns: Video object with thumbnail URL and original video storage path
  Future<Map<String, dynamic>> _convertVideoPathsToUrls(
    Map<String, dynamic> video,
  ) async {
    final updated = Map<String, dynamic>.from(video);

    if (updated['thumbnail_path'] != null) {
      final thumbnailPath = updated['thumbnail_path'] as String;
      final thumbnailUrl = _generatePublicUrl('my-thumbnails', thumbnailPath);
      updated['thumbnailUrl'] = thumbnailUrl;
      print('🔄 Convert thumbnail: "$thumbnailPath" → "$thumbnailUrl"');
    }

    if (updated['video_path'] != null) {
      final videoPath = updated['video_path'] as String;
      updated['video_path'] = videoPath;
      print('🔄 Preserve video path for lazy playback: "$videoPath"');
    }

    return updated;
  }

  Future<List<SportVideo>> _buildSportVideosFromRows(
    List<dynamic> rows,
  ) async {
    // Centralize the row -> URL-enriched map -> SportVideo conversion so every
    // public sport_videos method stays consistent.
    final videos = List<Map<String, dynamic>>.from(rows);
    final videosWithUrls = await Future.wait(
      videos.map(_convertVideoPathsToUrls),
    );
    return videosWithUrls.map(SportVideo.fromMap).toList();
  }

  /// Get videos from users that the current user follows (Following Feed)
  ///
  /// SECURITY: Uses auth.uid() server-side (not client-provided p_user_id)
  /// This prevents users from querying other users' follow graphs.
  ///
  /// How it works:
  /// 1. PostgreSQL function receives only limit + offset (no user ID parameter)
  /// 2. Function uses auth.uid() to get current logged-in user
  /// 3. Finds all users that auth.uid() is following
  /// 4. Returns their videos sorted by newest first
  /// 5. RLS on user_follows table restricts which rows the function can access
  ///
  /// Performance: ~20-50ms even with 100K+ follows
  /// (Database optimizer handles the subquery efficiently)
  ///
  /// Parameters:
  /// - [limit]: Videos per page (default: 50)
  /// - [offset]: Pagination offset for "load more" (default: 0)
  ///
  /// Returns: List of videos with usernames (includes username field for attribution)
  /// Each video: {id, title, description, video_path, thumbnail_path, thumbnailUrl, user_id,
  ///             view_count, average_rating, bayesian_score, total_ratings,
  ///             created_at, username}
  ///
  /// Security notes:
  /// - Function uses auth.uid() (caller's identity), not a passed-in user_id
  /// - RLS on user_follows restricts to only the caller's follows
  /// - RLS on sport_videos allows authenticated users to view all videos
  /// - RLS on user_personal_profiles allows authenticated users to view all usernames
  Future<List<SportVideo>> getFollowingVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      // Single RPC call to PostgreSQL function
      // Function uses auth.uid() internally (secure pattern)
      // Only pass limit + offset, not user_id
      final videos = await client.rpc(
        'get_following_videos',
        params: {'p_limit': limit, 'p_offset': offset},
      );

      if (videos.isEmpty) {
        print('✓ No videos from followed users yet');
        return [];
      }

      // Convert paths to URLs (service layer transformation)
      final videosWithUrls = await Future.wait(
        (videos as List<dynamic>).map(
          (v) => _convertVideoPathsToUrls(v as Map<String, dynamic>),
        ),
      );

      print(
        '✓ Fetched ${videosWithUrls.length} videos from followed users (RPC optimized)',
      );
      return videosWithUrls.map(SportVideo.fromMap).toList();
    } catch (e) {
      print('Error fetching following videos: $e');
      return <SportVideo>[];
    }
  }

  /// Fetch personalized videos based on user's watch history
  ///
  /// Returns videos from the user's top 5 engaged subcategories,
  /// sorted by quality (bayesian_score) in descending order.
  ///
  /// Logic:
  /// 1. Get top 5 subcategories from user's watch history (local storage)
  /// 2. Query sport_videos WHERE subcategory_id IN (top 5)
  /// 3. Order by bayesian_score DESC (best-rated videos first)
  /// 4. Include username via JOIN with user_personal_profiles
  /// 5. Apply pagination (limit, offset)
  ///
  /// Parameters:
  /// - [limit]: Number of videos to fetch per page (default: 50)
  /// - [offset]: Number of videos to skip for pagination (default: 0)
  ///
  /// Returns empty list if:
  /// - User hasn't watched any videos yet (no engagement data)
  /// - No videos exist in the user's engaged subcategories
  /// - An error occurs during fetch
  Future<List<SportVideo>> getPersonalizedVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Step 1: Get user's top 5 engaged subcategories from local storage
      final preferencesService = locator<PreferencesService>();
      final topSubcategories = await preferencesService.getTopSubcategories(
        limit: 5,
      );

      if (topSubcategories.isEmpty) {
        print(
          '✓ No watched subcategories yet - personalized feed will be empty',
        );
        return [];
      }

      // Step 2: Extract subcategory IDs
      final subcategoryIds = topSubcategories.map((e) => e.key).toList();
      print(
        '📊 Personalized feed: fetching videos from subcategories: $subcategoryIds',
      );

      // Step 3: Query videos WHERE subcategory_id IN (top 5 engaged categories)
      // Now uses FK-based nested select for username in ONE query (no N+1!)
      // Order by bayesian_score DESC (best-rated videos first)
      // Use range(start, end) for pagination instead of limit + offset
      // Use column projection to reduce network payload (~40% smaller)
      final videos = await client
          .from('sport_videos')
          .select(
            'id, user_id, user_video_id, title, thumbnail_path, video_path, average_rating, total_ratings, bayesian_score, view_count, sport_id, user_personal_profiles(username)',
          )
          .inFilter('subcategory_id', subcategoryIds)
          .order('bayesian_score', ascending: false)
          .range(offset, offset + limit - 1);

      if (videos.isEmpty) {
        print('✓ No videos in top subcategories yet');
        return [];
      }

      final sportVideos = await _buildSportVideosFromRows(
        videos,
      );

      print(
        '✓ Fetched ${sportVideos.length} personalized videos from top 5 engaged categories (bayesian_score sorted)',
      );
      return sportVideos;
    } catch (e) {
      print('Error fetching personalized videos: $e');
      return <SportVideo>[];
    }
  }

  /// Fetch trending videos based on quality and recency
  ///
  /// Returns highest-rated videos from the last 7 days,
  /// sorted by bayesian_score in descending order.
  ///
  /// Logic:
  /// 1. Filter videos posted in the last 7 days (created_at > 7 days ago)
  /// 2. Order by bayesian_score DESC (best-rated videos first)
  /// 3. Include username via JOIN with user_personal_profiles
  /// 4. Apply pagination (limit, offset)
  ///
  /// Parameters:
  /// - [limit]: Number of videos to fetch per page (default: 50)
  /// - [offset]: Number of videos to skip for pagination (default: 0)
  ///
  /// Returns empty list if:
  /// - No videos exist in the last 7 days
  /// - All videos have low/zero ratings
  /// - An error occurs during fetch
  ///
  /// Performance:
  /// - Optimized by idx_sport_videos_created_bayesian index
  /// - Filters by created_at range first, then sorts by bayesian_score
  Future<List<SportVideo>> getTrendingVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Calculate cutoff timestamp: 7 days ago in UTC
      // Using UTC ensures consistency with Supabase PostgreSQL (always UTC)
      // toIso8601String() format: "2026-06-04T14:30:00.000Z"
      final sevenDaysAgo = DateTime.now()
          .toUtc()
          .subtract(Duration(days: 7))
          .toIso8601String();

      print(
        '🔥 Trending feed: fetching videos from last 7 days (after $sevenDaysAgo)',
      );

      // Query videos posted in last 7 days
      // Now uses FK-based nested select for username in ONE query (no N+1!)
      // Order by bayesian_score DESC (best-rated videos first, not newest)
      // Use column projection to reduce network payload (~40% smaller)
      final videos = await client
          .from('sport_videos')
          .select(
            'id, user_id, user_video_id, title, thumbnail_path, video_path, average_rating, total_ratings, bayesian_score, view_count, sport_id, user_personal_profiles(username)',
          )
          .gt('created_at', sevenDaysAgo) // created_at > 7 days ago
          .order('bayesian_score', ascending: false) // Best-rated first
          .range(offset, offset + limit - 1); // Pagination

      if (videos.isEmpty) {
        print('✓ No trending videos in the last 7 days');
        return [];
      }

      final sportVideos = await _buildSportVideosFromRows(videos);

      print(
        '✓ Fetched ${sportVideos.length} trending videos from last 7 days (bayesian_score sorted)',
      );
      return sportVideos;
    } catch (e) {
      print('Error fetching trending videos: $e');
      return <SportVideo>[];
    }
  }

  /// Fetch random discovery videos from unwatched categories
  ///
  /// Returns random videos from subcategories the user has NOT watched,
  /// enabling content discovery outside their comfort zone.
  ///
  /// Logic:
  /// 1. Get user's top 5 engaged subcategories from local storage
  /// 2. Query videos WHERE subcategory_id NOT IN (top 5)
  /// 3. Shuffle in Dart for true randomness
  /// 4. Include username via JOIN with user_personal_profiles
  /// 5. Return limit videos (NO pagination - refresh for new random videos)
  ///
  /// Parameters:
  /// - [limit]: Number of discovery videos to fetch (default: 50)
  ///   No offset parameter - each call returns fresh random batch
  ///
  /// Returns empty list if:
  /// - User hasn't watched any videos yet (all videos shown)
  /// - No videos exist outside user's top 5 categories
  /// - An error occurs during fetch
  ///
  /// UX Pattern:
  /// - User swipes through all 50 videos
  /// - Reaches bottom, taps "Load More" or pulls to refresh
  /// - New random 50 videos returned (no duplicates from pagination)
  /// - Matches TikTok/Instagram Explore pattern (refresh = new random)
  ///
  /// Note: Uses client-side shuffle (Dart List.shuffle()) instead of database
  /// ORDER BY RANDOM() for compatibility with Supabase Dart v2.12.4
  Future<List<SportVideo>> getDiscoveryVideos({
    int limit = 50,
    Set<String> excludedVideoIds = const <String>{},
  }) async {
    try {
      final preferencesService = locator<PreferencesService>();
      final topSubcategories = await preferencesService.getTopSubcategories(
        limit: 5,
      );

      final excludedSubcategoryIds = topSubcategories
          .map((entry) => int.tryParse(entry.key))
          .whereType<int>()
          .toList(growable: false);

      if (topSubcategories.isNotEmpty && excludedSubcategoryIds.isEmpty) {
        print(
          '⚠️ Discovery RPC: top subcategory keys were not numeric, sending no subcategory exclusions: ${topSubcategories.map((entry) => entry.key).toList()}',
        );
      }

      final response = await client.rpc(
        'get_discovery_videos',
        params: {
          'p_limit': limit,
          'p_seen_video_ids': excludedVideoIds.toList(growable: false),
          'p_excluded_subcategory_ids': excludedSubcategoryIds,
        },
      );

      final videos = List<dynamic>.from(response as List<dynamic>);

      if (videos.isEmpty) {
        print('✓ No deterministic discovery videos available');
        return [];
      }

      final sportVideos = await _buildSportVideosFromRows(videos);

      print(
        '✓ Fetched ${sportVideos.length} deterministic discovery videos (excluded=${excludedVideoIds.length})',
      );
      return sportVideos;
    } catch (e) {
      print('Error fetching deterministic discovery videos: $e');
      return <SportVideo>[];
    }
  }

  Future<List<SportVideo>> getRandomDiscoveryVideos({
    int limit = 50,
  }) async {
    try {
      // Step 1: Get user's top 5 engaged subcategories from local storage
      final preferencesService = locator<PreferencesService>();
      final topSubcategories = await preferencesService.getTopSubcategories(
        limit: 5,
      );

      // Step 2a: If no watch history, show ALL videos (everything is new discovery)
      if (topSubcategories.isEmpty) {
        print(
          '🎲 Discovery: No watch history - showing random videos from ALL categories',
        );

        // Fetch extra to ensure we have enough after shuffling
        // Now uses FK-based nested select for username in ONE query (no N+1!)
        // Use column projection to reduce network payload (~40% smaller)
        final allVideos = await client
            .from('sport_videos')
            .select(
              'id, user_id, user_video_id, title, thumbnail_path, video_path, average_rating, total_ratings, bayesian_score, view_count, sport_id, user_personal_profiles(username)',
            )
            .limit(limit * 2); // Fetch 2x limit for better randomness

        if (allVideos.isEmpty) {
          print('✓ No discovery videos available');
          return [];
        }

        // Shuffle in Dart and take limit
        (allVideos as List).shuffle();
        final randomVideos = allVideos.take(limit).toList();

        final sportVideos = await _buildSportVideosFromRows(randomVideos);

        print(
          '✓ Fetched ${sportVideos.length} random discovery videos from all categories',
        );
        return sportVideos;
      }

      // Step 2b: Extract subcategory IDs to exclude
      final unwatchedSubcategoryIds = topSubcategories
          .map((e) => e.key)
          .toList();
      print(
        '🎲 Discovery: fetching random videos NOT from: $unwatchedSubcategoryIds',
      );

      // Step 3: Query videos NOT in user's top 5 categories
      // Fetch extra to ensure we have enough after shuffling
      // Each call returns different random batch via Dart's shuffle
      // Now uses FK-based nested select for username in ONE query (no N+1!)
      // Use column projection to reduce network payload (~40% smaller)
      final allDiscoveryVideos = await client
          .from('sport_videos')
          .select(
            'id, user_id, user_video_id, title, thumbnail_path, video_path, average_rating, total_ratings, bayesian_score, view_count, sport_id, user_personal_profiles(username)',
          )
          .not(
            'subcategory_id',
            'in',
            _toPostgrestInList(List<Object>.from(unwatchedSubcategoryIds)),
          )
          .limit(limit * 2); // Fetch 2x limit for better randomness

      if (allDiscoveryVideos.isEmpty) {
        print(
          '✓ No discovery videos available outside top categories (user has watched most sports)',
        );
        return [];
      }

      // Shuffle in Dart and take limit
      (allDiscoveryVideos as List).shuffle();
      final randomDiscoveryVideos = allDiscoveryVideos.take(limit).toList();

      final sportVideos = await _buildSportVideosFromRows(
        randomDiscoveryVideos,
      );

      print(
        '✓ Fetched ${sportVideos.length} random discovery videos (new random batch each call)',
      );
      return sportVideos;
    } catch (e) {
      print('Error fetching discovery videos: $e');
      return <SportVideo>[];
    }
  }
}
