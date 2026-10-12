import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';

/// Service boundary for Home feed pagination.
///
/// Feed assembly happens in the `get_home_feed_page_v2` RPC, which applies the
/// 40/30/20/10 source mix, sparse-source backfill, and keyset pagination.
class HomeFeedService {
  final supabaseService = locator<SupabaseService>();

  /// Fetch the next batch for an existing home-feed session.
  ///
  /// Pass [HomeFeedCursor.initial] to start a new session, otherwise the
  /// `nextCursor` from the previous page.
  Future<Map<String, dynamic>> getHomeFeedContinuation({
    HomeFeedCursor cursor = const HomeFeedCursor.initial(),
    int limit = 20,
  }) async {
    return supabaseService.getHomeFeedPage(cursor: cursor, limit: limit);
  }
}
