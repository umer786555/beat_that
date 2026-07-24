import 'dart:io';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:mime/mime.dart';

/// DioUploadService handles file uploads to Supabase Storage with progress tracking
/// 
/// Features:
/// - JWT token authentication from Supabase session
/// - Upload progress callbacks for UI updates
/// - Automatic MIME type detection
/// - Error handling and validation
/// - Support for multiple file types
/// 
/// Usage:
/// ```dart
/// final uploadService = DioUploadService();
/// await uploadService.uploadFile(
///   file: videoFile,
///   bucketName: 'my-videos',
///   path: 'profiles/user123/videos/video.mp4',
///   onProgress: (sent, total) {
///     print('${(sent/total*100).toStringAsFixed(0)}% uploaded');
///   },
/// );
/// ```
class DioUploadService {
  late final Dio _dio;
  late final String _baseUrl;

  /// Initialize DioUploadService with the active Supabase project's storage URL
  DioUploadService() {
    _baseUrl = '${supabase.Supabase.instance.client.storage.url}/object';
    
    _dio = Dio(_getBaseOptions());
    _addInterceptors();
  }

  /// Get base options for Dio configuration
  /// 
  /// Configures:
  /// - Timeout settings
  /// - Default headers
  /// - Response type
  BaseOptions _getBaseOptions() {
    return BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }

  /// Add interceptors for logging and authentication
  void _addInterceptors() {
    // Log interceptor for debugging
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (o) => print('[DIO] ${o.toString()}'),
      ),
    );

    // Custom auth interceptor to add JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = supabase.Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Upload a file to Supabase Storage with progress tracking
  ///
  /// Parameters:
  /// - [file]: The file to upload
  /// - [bucketName]: Supabase bucket name (e.g., 'my-videos')
  /// - [path]: Storage path (e.g., 'profiles/user123/videos/video.mp4')
  /// - [onProgress]: Callback for upload progress (sent bytes, total bytes)
  ///
  /// Returns: The full upload URL
  /// 
  /// Throws: [DioException] if upload fails
  Future<String> uploadFile({
    required File file,
    required String bucketName,
    required String path,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Validate file exists
      if (!await file.exists()) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          error: 'File not found: ${file.path}',
          type: DioExceptionType.badResponse,
        );
      }

      // Build full upload URL from base URL + bucket + path
      final uploadUrl = '$_baseUrl/$bucketName/$path';
      print('📤 Uploading to: $uploadUrl');

      // Get MIME type
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSizeInMB = (await file.length()) / (1000 * 1000);
      print('📦 File size: ${fileSizeInMB.toStringAsFixed(2)} MB');
      print('📋 MIME type: $mimeType');

      // Perform upload with progress tracking
      final fileStream = file.openRead();
      final response = await _dio.request(
        uploadUrl,
        data: fileStream,
        options: Options(
          method: 'PUT',
          contentType: mimeType,
          headers: {
            'x-upsert': 'true', // Allow overwrite if file exists
            'content-length': await file.length(),
          },
        ),
        onSendProgress: onProgress,
      );


      // Validate response
      if (response.statusCode == null || response.statusCode! > 299) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Upload failed with status ${response.statusCode}',
        );
      }

      print('✅ Upload successful! URL: $uploadUrl');
      return uploadUrl;
    } on DioException catch (e) {
      print('❌ Upload error: ${e.message}');
      print('📌 Error type: ${e.type}');
      if (e.response != null) {
        print('📌 Status code: ${e.response?.statusCode}');
        print('📌 Response: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Unexpected error: $e');
      rethrow;
    }
  }

  /// Close Dio instance and clean up resources
  void dispose() {
    _dio.close();
    print('🧹 DioUploadService disposed');
  }
}
