import 'package:flutter/foundation.dart';

/// Supabase configuration for the Beat That app
class SupabaseConfig {
  /// Get the Supabase project URL based on build mode
  static String getSupabaseUrl() {
    if (kDebugMode) {
      return 'https://hsyqamsignfrbsifrkmu.supabase.co';
    } else {
      return 'https://ahrpqdjrnriugjdxqkfy.supabase.co';
    }
  }
}
