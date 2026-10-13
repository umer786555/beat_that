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
    on<FetchFeedEvent>(_onFetchFeed);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
    on<MergeVideoFeedSessionEvent>(_onMergeVideoFeedSession);
  }

  static const int _homeFeedPageSize = 24;

  final PreferencesService _preferencesService;
  final SupabaseService _supabaseService;
  final HomeFeedService _homeFeedService;
  final AuthService _authService;

  // Session-scoped feed state; `_seenFeedVideoIds` guards against rare repeats
  // when follows change mid-session.
  List<SportVideo> _allFeedVideos = [];
  final Set<String> _seenFeedVideoIds = <String>{};
  HomeFeedCursor _feedCursor = const HomeFeedCursor.initial();
  bool _hasMoreFeedContent = true;
  bool _isPaginationRequestInFlight = false;

  /// Handle InitialEvent - save user profile and fetch initial feed
  Future<void> _onInitial(InitialEvent event, Emitter<HomeState> emit) async {
    try {
      await _preferencesService.clearUserProfile();

      final hasFullAccountAccess = _authService.hasFullAccountAccess();

      if (!hasFullAccountAccess) {
        add(const FetchFeedEvent(limit: _homeFeedPageSize, offset: 0));
        return;
      }

      // Fetch user profile from Supabase
      final userProfile = await _supabaseService.fetchUserPersonalProfile();

      if (userProfile != null) {
        // Save to preferences for offline access
        await _preferencesService.saveUserProfile(userProfile);

        // Automatically fetch initial feed after saving profile
        add(const FetchFeedEvent(limit: _homeFeedPageSize, offset: 0));
      } else {
        emit(const NoUserProfile());
      }
    } catch (e) {
      debugPrint('[HOME] Failed to load user profile: $e');
      emit(FeedError(message: 'Failed to load user profile: $e'));
    }
  }

  /// Handle FetchFeedEvent by requesting the next RPC-backed Home feed page.
  Future<void> _onFetchFeed(
    FetchFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // Emit loading state
      final isFirstLoad = event.offset == 0;
      emit(FeedLoading(offset: event.offset, isFirstLoad: isFirstLoad));

      final feedResult = await _homeFeedService.getHomeFeedContinuation(
        cursor: event.offset == 0
            ? const HomeFeedCursor.initial()
            : _feedCursor,
        limit: event.limit,
      );
      final videos = List<SportVideo>.from(
        feedResult['videos'] as List<dynamic>,
      );
      final nextCursor = feedResult['nextCursor'] as HomeFeedCursor;
      final hasMoreContent = feedResult['hasMoreContent'] as bool;
      _feedCursor = nextCursor;

      if (videos.isEmpty) {
        _hasMoreFeedContent = hasMoreContent;
        emit(
          FeedLoaded(
            videos: List<SportVideo>.from(_allFeedVideos),
            offset: event.offset,
            hasMoreContent: hasMoreContent,
            nextCursor: nextCursor,
          ),
        );
        return;
      }

      final uniqueVideos = videos.where((video) {
        final videoId = video.id;
        return !_seenFeedVideoIds.contains(videoId);
      }).toList();

      // For pagination: append new videos to existing list if offset > 0
      if (event.offset == 0) {
        _allFeedVideos = uniqueVideos;
        _seenFeedVideoIds
          ..clear()
          ..addAll(uniqueVideos.map((video) => video.id));
      } else {
        _allFeedVideos = [..._allFeedVideos, ...uniqueVideos];
        _seenFeedVideoIds.addAll(uniqueVideos.map((video) => video.id));
      }

      _hasMoreFeedContent = hasMoreContent;

      emit(
        FeedLoaded(
          videos: List<SportVideo>.from(_allFeedVideos),
          offset: event.offset,
          hasMoreContent: hasMoreContent,
          nextCursor: nextCursor,
        ),
      );
    } catch (e) {
      debugPrint('[HOME] Failed to load feed: $e');
      emit(FeedError(message: 'Failed to load feed: $e', offset: event.offset));
    } finally {
      if (event.offset > 0) {
        _isPaginationRequestInFlight = false;
      }
    }
  }

  /// Handle RefreshFeedEvent - refresh feed from the top
  ///
  /// Clears cache and fetches fresh feed starting from offset=0
  void _onRefreshFeed(RefreshFeedEvent event, Emitter<HomeState> emit) {
    // Clear cache and reset pagination
    _allFeedVideos = [];
    _seenFeedVideoIds.clear();
    _feedCursor = const HomeFeedCursor.initial();
    _hasMoreFeedContent = true;
    _isPaginationRequestInFlight = false;

    // Fetch fresh feed from top
    add(const FetchFeedEvent(limit: _homeFeedPageSize, offset: 0));
  }

  /// Handle LoadMoreFeedEvent - load next page of feed
  ///
  /// Fetches next batch using current offset
  void _onLoadMoreFeed(LoadMoreFeedEvent event, Emitter<HomeState> emit) {
    if (!_hasMoreFeedContent || _isPaginationRequestInFlight) return;

    _isPaginationRequestInFlight = true;

    // Fetch next batch at current offset
    add(
      FetchFeedEvent(limit: _homeFeedPageSize, offset: _allFeedVideos.length),
    );
  }

  void _onMergeVideoFeedSession(
    MergeVideoFeedSessionEvent event,
    Emitter<HomeState> emit,
  ) {
    final videos = event.videos;
    if (state is! FeedLoaded ||
        _isPaginationRequestInFlight ||
        videos.length <= _allFeedVideos.length) {
      return;
    }

    // Only extend the grid if the session continues the grid's list exactly.
    for (var i = 0; i < _allFeedVideos.length; i++) {
      if (videos[i].id != _allFeedVideos[i].id) return;
    }

    final previousCount = _allFeedVideos.length;
    _allFeedVideos = List<SportVideo>.from(videos);
    _seenFeedVideoIds.addAll(videos.map((video) => video.id));
    _feedCursor = event.nextCursor;
    _hasMoreFeedContent = event.hasMoreContent;

    emit(
      FeedLoaded(
        videos: List<SportVideo>.from(_allFeedVideos),
        offset: previousCount,
        hasMoreContent: event.hasMoreContent,
        nextCursor: event.nextCursor,
      ),
    );
  }
}
