import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    PreferencesService? preferencesService,
    SupabaseService? supabaseService,
    HomeFeedService? homeFeedService,
    AuthService? authService,
  }) : _preferencesService =
           preferencesService ?? locator<PreferencesService>(),
       _supabaseService = supabaseService ?? locator<SupabaseService>(),
       _homeFeedService = homeFeedService ?? locator<HomeFeedService>(),
       _authService = authService ?? locator<AuthService>(),
       super(HomeInitial()) {
    on<InitialEvent>(_onInitial);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
    on<MergeVideoFeedSessionEvent>(_onMergeVideoFeedSession);
  }

  static const int _homeFeedPageSize = 24;

  final PreferencesService _preferencesService;
  final SupabaseService _supabaseService;
  final HomeFeedService _homeFeedService;
  final AuthService _authService;

  /// Bumped on every first-page fetch so an older in-flight page is dropped.
  int _feedGeneration = 0;

  /// Handle InitialEvent - save user profile and fetch initial feed
  Future<void> _onInitial(InitialEvent event, Emitter<HomeState> emit) async {
    try {
      await _preferencesService.clearUserProfile();

      if (_authService.hasFullAccountAccess()) {
        final userProfile = await _supabaseService.fetchUserPersonalProfile();
        if (userProfile == null) {
          emit(const NoUserProfile());
          return;
        }

        // Save to preferences for offline access
        await _preferencesService.saveUserProfile(userProfile);
      }
    } catch (e) {
      debugPrint('[HOME] Failed to load user profile: $e');
      emit(FeedError(message: 'Failed to load user profile: $e'));
      return;
    }

    await _fetchFeed(emit);
  }

  /// Handle RefreshFeedEvent - refresh feed from the top
  Future<void> _onRefreshFeed(
    RefreshFeedEvent event,
    Emitter<HomeState> emit,
  ) => _fetchFeed(emit);

  /// Handle LoadMoreFeedEvent - append the next page to the loaded feed
  Future<void> _onLoadMoreFeed(
    LoadMoreFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded ||
        current.isLoadingMore ||
        !current.hasMoreContent) {
      return;
    }

    await _fetchFeed(emit, appendTo: current);
  }

  /// Fetches the first page, or the next page after [appendTo].
  ///
  /// Videos already in [appendTo] are filtered out of the new page.
  Future<void> _fetchFeed(
    Emitter<HomeState> emit, {
    FeedLoaded? appendTo,
  }) async {
    final generation = appendTo == null ? ++_feedGeneration : _feedGeneration;

    // Emitted before the first await so a second load-more sees the guard.
    emit(
      appendTo == null
          ? const FeedLoading()
          : FeedLoaded(
              videos: appendTo.videos,
              offset: appendTo.offset,
              hasMoreContent: appendTo.hasMoreContent,
              nextCursor: appendTo.nextCursor,
              isLoadingMore: true,
            ),
    );

    try {
      final feedResult = await _homeFeedService.getHomeFeedContinuation(
        cursor: appendTo?.nextCursor ?? const HomeFeedCursor.initial(),
        limit: _homeFeedPageSize,
      );
      // A refresh started while this page was in flight.
      if (generation != _feedGeneration) return;

      final existing = appendTo?.videos ?? const <SportVideo>[];
      final existingIds = {for (final video in existing) video.id};
      final newVideos = [
        for (final video in feedResult['videos'] as List<dynamic>)
          if (!existingIds.contains((video as SportVideo).id)) video,
      ];

      emit(
        FeedLoaded(
          videos: [...existing, ...newVideos],
          offset: existing.length,
          hasMoreContent: feedResult['hasMoreContent'] as bool,
          nextCursor: feedResult['nextCursor'] as HomeFeedCursor,
        ),
      );
    } catch (e) {
      if (generation != _feedGeneration) return;
      debugPrint('[HOME] Failed to load feed: $e');
      emit(FeedError(message: 'Failed to load feed: $e'));
    }
  }

  void _onMergeVideoFeedSession(
    MergeVideoFeedSessionEvent event,
    Emitter<HomeState> emit,
  ) {
    final current = state;
    final videos = event.videos;
    if (current is! FeedLoaded ||
        current.isLoadingMore ||
        videos.length <= current.videos.length) {
      return;
    }

    // Only extend the grid if the session continues the grid's list exactly.
    for (var i = 0; i < current.videos.length; i++) {
      if (videos[i].id != current.videos[i].id) return;
    }

    emit(
      FeedLoaded(
        videos: List<SportVideo>.of(videos),
        offset: current.videos.length,
        hasMoreContent: event.hasMoreContent,
        nextCursor: event.nextCursor,
      ),
    );
  }
}
