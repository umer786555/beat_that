import 'dart:io';

import 'package:beat_that/services/supabase_service.dart';

/// Turns a stored `videoPath` into something a player can open.
class VideoSourceResolver {
  VideoSourceResolver({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  /// Returns http(s) URLs unchanged and existing local files as paths;
  /// anything else is a storage path that Supabase resolves.
  Future<String> resolve(String videoPath) async {
    if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
      return videoPath;
    }
    if (await File(videoPath).exists()) {
      return videoPath;
    }
    return _supabaseService.resolveVideoPlaybackUrl(videoPath);
  }
}
