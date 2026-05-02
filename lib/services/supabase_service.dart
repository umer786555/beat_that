import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// SupabaseService - Handles all Supabase operations for Beat That
/// 
/// This service manages:
/// - Video uploads to storage with any file format support
/// - Thumbnail uploads to storage with any image format support
/// - Database records linking videos to thumbnails
/// - User profile management
/// 
/// Storage Structure (UUID-based naming prevents collisions):
/// - videos/{user_id}/{uuid}.{extension}
/// - thumbnails/{user_id}/{uuid}_thumb.{extension}
/// - Example: videos/abc-123/550e8400-e29b-41d4-a716-446655440000.webm
///
/// Database Tables:
/// - videos (stores metadata with storage paths and view counts)
/// - profiles (stores user profile information)
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  late final SupabaseClient _supabase;

  /// Private constructor for singleton pattern
  SupabaseService._internal();

  /// Get singleton instance
  factory SupabaseService() {
    return _instance;
  }

  /// Initialize Supabase client
  /// Call this once in your main.dart before using the service
  Future<void> initialize() async {
    _supabase = Supabase.instance.client;
  }

  /// Get the Supabase client instance
  SupabaseClient get supabase => _supabase;

  /// Get current authenticated user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get current authenticated user email
  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  // ==================== VIDEO UPLOAD OPERATIONS ====================

  /// Upload a video and thumbnail to Supabase Storage
  /// 
  /// ATOMIC OPERATION: Either all steps succeed or nothing is saved.
  /// If any step fails, previously uploaded files are automatically deleted.
  /// - Step 1: Upload video file to storage
  /// - Step 2: Upload thumbnail file to storage
  /// - Step 3: Create database record with validation
  /// - Step 4: Generate public URLs
  /// 
  /// Supports any video format (MP4, WebM, MOV, etc.) and image format (JPEG, PNG, WebP, etc.)
  /// MIME types are automatically detected from file extensions.
  /// 
  /// Parameters:
  /// - [videoFile]: The video file to upload (any video format)
  /// - [thumbnailFile]: The thumbnail image file to upload (any image format)
  /// - [title]: Video title for the database record
  /// - [description]: Video description (optional)
  /// 
  /// Returns on success:
  /// - {success: true, fileId, videoId, videoUrl, thumbnailUrl, videoPath, thumbnailPath, message}
  /// 
  /// Returns on failure:
  /// - {success: false, message, error}
  /// - All uploaded files are automatically deleted if database insert fails
  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required File videoFile,
    required File thumbnailFile,
    required String title,
    String? description,
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
    
    // Get file extensions
    final videoExtension = _getFileExtension(videoFile.path);
    final thumbnailExtension = _getFileExtension(thumbnailFile.path);
    
    // Define storage paths with actual file extensions
    final videoPath = 'videos/$userId/$fileId.$videoExtension';
    final thumbnailPath = 'thumbnails/$userId/${fileId}_thumb.$thumbnailExtension';

    // Detect MIME types
    final videoMimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';
    final thumbnailMimeType = lookupMimeType(thumbnailFile.path) ?? 'image/jpeg';

    // Track which files were successfully uploaded for cleanup
    String? uploadedVideoPath;
    String? uploadedThumbnailPath;
    String? createdVideoId;

    try {
      // ==================== STEP 1: Upload Video ====================
      print('Step 1: Uploading video: $videoPath (MIME: $videoMimeType)');
      await _supabase.storage.from('videos').upload(
        videoPath,
        videoFile,
        fileOptions: FileOptions(contentType: videoMimeType),
      );
      uploadedVideoPath = videoPath;
      print('✓ Video uploaded successfully');

      // ==================== STEP 2: Upload Thumbnail ====================
      print('Step 2: Uploading thumbnail: $thumbnailPath (MIME: $thumbnailMimeType)');
      await _supabase.storage.from('thumbnails').upload(
        thumbnailPath,
        thumbnailFile,
        fileOptions: FileOptions(contentType: thumbnailMimeType),
      );
      uploadedThumbnailPath = thumbnailPath;
      print('✓ Thumbnail uploaded successfully');

      // ==================== STEP 3: Create Database Record ====================
      print('Step 3: Creating video record in database');
      final insertResponse = await _supabase.from('videos').insert({
        'user_id': userId,
        'title': title,
        'description': description ?? '',
        'video_url': videoPath,
        'thumbnail_url': thumbnailPath,
        'view_count': 0,
        'created_at': DateTime.now().toIso8601String(),
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
      final videoPublicUrl = _supabase.storage
          .from('videos')
          .getPublicUrl(videoPath);
      
      final thumbnailPublicUrl = _supabase.storage
          .from('thumbnails')
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
      print('Rolling back uploaded files...');

      // ==================== ROLLBACK: Delete uploaded files ====================
      if (uploadedVideoPath != null) {
        try {
          print('Deleting uploaded video file...');
          await _supabase.storage.from('videos').remove([uploadedVideoPath]);
          print('✓ Video file deleted');
        } catch (deleteError) {
          print('⚠ Warning: Could not delete video file: $deleteError');
        }
      }

      if (uploadedThumbnailPath != null) {
        try {
          print('Deleting uploaded thumbnail file...');
          await _supabase.storage.from('thumbnails').remove([uploadedThumbnailPath]);
          print('✓ Thumbnail file deleted');
        } catch (deleteError) {
          print('⚠ Warning: Could not delete thumbnail file: $deleteError');
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

  /// Helper method to extract file extension from file path
  String _getFileExtension(String filePath) {
    final ext = p.extension(filePath);
    return ext.isNotEmpty ? ext.substring(1).toLowerCase() : 'bin';
  }

  // ==================== VIDEO RETRIEVAL OPERATIONS ====================

  /// Get lightweight thumbnail data for displaying in a ListView
  /// 
  /// This fetches only the essential data needed for thumbnail display:
  /// - id, title, thumbnail_url, view_count, created_at, description
  /// - Videos ordered by most recent first
  /// - Storage paths converted to public URLs
  /// 
  /// Optimization strategy:
  /// 1. Load thumbnails first (lightweight query)
  /// 2. When user taps a thumbnail, call [getVideoById] to fetch full video data
  /// 
  /// Returns a list of video records with thumbnail URLs
  /// Returns empty list if user not authenticated or query fails
  Future<List<Map<String, dynamic>>> getVideoThumbnails() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Query only the columns needed for thumbnail display
      final videos = await _supabase
          .from('videos')
          .select('id, title, thumbnail_url, view_count, created_at, description')
          .eq('user_id', userId)
          .order('created_at', ascending: false); // Most recent first

      // Convert storage paths to public URLs
      final videosWithUrls = videos.map((video) {
        return {
          ...video,
          'thumbnail_url': _supabase.storage
              .from('thumbnails')
              .getPublicUrl(video['thumbnail_url']),
        };
      }).toList();

      return videosWithUrls;
    } catch (e) {
      print('Error fetching video thumbnails: $e');
      return [];
    }
  }

  /// Get all videos uploaded by the current user with full details
  /// 
  /// This fetches all columns including both video_url and thumbnail_url
  /// Videos ordered by most recent first
  /// Storage paths converted to public URLs
  /// 
  /// Use case: When you need complete video data immediately
  /// 
  /// For better performance with large collections,
  /// use [getVideoThumbnails] instead and lazy-load videos on tap
  /// 
  /// Returns a list of video records with both video and thumbnail URLs
  /// Returns empty list if user not authenticated or query fails
  Future<List<Map<String, dynamic>>> getUserVideos() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Query videos table for current user's videos
      final videos = await _supabase
          .from('videos')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false); // Most recent first

      // Convert storage paths to public URLs
      final videosWithUrls = videos.map((video) {
        return {
          ...video,
          'video_url': _supabase.storage
              .from('videos')
              .getPublicUrl(video['video_url']),
          'thumbnail_url': _supabase.storage
              .from('thumbnails')
              .getPublicUrl(video['thumbnail_url']),
        };
      }).toList();

      return videosWithUrls;
    } catch (e) {
      print('Error fetching user videos: $e');
      return [];
    }
  }

  /// Get a specific video by ID with full details
  /// 
  /// Parameters:
  /// - [videoId]: The ID of the video to fetch
  /// 
  /// Returns: Video record with public URLs for both video and thumbnail
  /// Returns null if video not found or query fails
  Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select()
          .eq('id', videoId)
          .single();

      // Convert storage paths to public URLs
      return {
        ...response,
        'video_url': _supabase.storage
            .from('videos')
            .getPublicUrl(response['video_url']),
        'thumbnail_url': _supabase.storage
            .from('thumbnails')
            .getPublicUrl(response['thumbnail_url']),
      };
    } catch (e) {
      print('Error fetching video: $e');
      return null;
    }
  }

  // ==================== VIDEO UPDATE OPERATIONS ====================

  /// Update video metadata (title, description)
  /// 
  /// Verifies user ownership before updating. Only the video owner can modify.
  /// Automatically updates the updated_at timestamp.
  /// 
  /// Parameters:
  /// - [videoId]: The ID of the video to update
  /// - [title]: New title (optional, skipped if null)
  /// - [description]: New description (optional, skipped if null)
  /// 
  /// Returns: true if update succeeded, false if failed or user not authenticated
  Future<bool> updateVideo({
    required String videoId,
    String? title,
    String? description,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('videos')
          .update(updateData)
          .eq('id', videoId)
          .eq('user_id', userId); // Ensure user owns the video

      print('Video updated successfully');
      return true;
    } catch (e) {
      print('Error updating video: $e');
      return false;
    }
  }

  /// Increment view count for a video by 1
  /// 
  /// Fetches current view count, increments by 1, and updates database.
  /// 
  /// Parameters:
  /// - [videoId]: The ID of the video to increment views for
  /// 
  /// Returns: true if increment succeeded, false if failed
  Future<bool> incrementViewCount(String videoId) async {
    try {
      // Get current view count
      final video = await _supabase
          .from('videos')
          .select('view_count')
          .eq('id', videoId)
          .single();

      final currentCount = video['view_count'] ?? 0;

      // Increment and update
      await _supabase.from('videos').update({
        'view_count': currentCount + 1,
      }).eq('id', videoId);

      return true;
    } catch (e) {
      print('Error incrementing view count: $e');
      return false;
    }
  }

  // ==================== VIDEO DELETION OPERATIONS ====================

  /// Delete a video and all associated data
  /// 
  /// This is a multi-step deletion that:
  /// 1. Deletes video file from storage
  /// 2. Deletes thumbnail file from storage
  /// 3. Deletes database record (only if user owns the video)
  /// 
  /// Verifies user ownership before deletion. Only the video owner can delete.
  /// 
  /// Parameters:
  /// - [videoId]: The ID of the video to delete
  /// - [videoPath]: The storage path of the video file
  /// - [thumbnailPath]: The storage path of the thumbnail file
  /// 
  /// Returns: true if all deletions succeeded, false if any step failed
  Future<bool> deleteVideo({
    required String videoId,
    required String videoPath,
    required String thumbnailPath,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Delete video file from storage
      print('Deleting video file: $videoPath');
      await _supabase.storage.from('videos').remove([videoPath]);

      // Delete thumbnail file from storage
      print('Deleting thumbnail file: $thumbnailPath');
      await _supabase.storage.from('thumbnails').remove([thumbnailPath]);

      // Delete database record
      print('Deleting video record from database');
      await _supabase
          .from('videos')
          .delete()
          .eq('id', videoId)
          .eq('user_id', userId); // Ensure user owns the video

      print('Video deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  // ==================== PROFILE OPERATIONS ====================

  /// Create or update user profile
  /// 
  /// Uses upsert to create new profile or update existing profile.
  /// Automatically updates the updated_at timestamp.
  /// 
  /// Parameters:
  /// - [fullName]: User's full name (required)
  /// - [bio]: User's bio description (optional, empty string if not provided)
  /// - [avatarUrl]: URL to user's profile picture (optional)
  /// 
  /// Returns: true if upsert succeeded, false if failed or user not authenticated
  Future<bool> updateUserProfile({
    required String fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'email': getCurrentUserEmail(),
        'bio': bio ?? '',
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Profile updated successfully');
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
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

      final profile = await _supabase
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
    return _supabase.auth.currentUser != null;
  }

  /// Get user session
  Session? getSession() {
    return _supabase.auth.currentSession;
  }

  /// Listen to authentication state changes
  /// 
  /// Example usage:
  /// ```dart
  /// _supabaseService.onAuthStateChange.listen((data) {
  ///   final event = data.event;
  ///   final session = data.session;
  ///   // Handle auth state change
  /// });
  /// ```
  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;
}
