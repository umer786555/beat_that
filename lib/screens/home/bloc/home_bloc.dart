import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const int _homeFeedPageSize = 24;

  final preferencesService = locator<PreferencesService>();
  final supabaseService = locator<SupabaseService>();
  final homeFeedService = locator<HomeFeedService>();
  final authService = locator<AuthService>();

  // Track pagination state
  int _currentOffset = 0;
  List<Map<String, dynamic>> _allFeedVideos = [];
  final Set<String> _seenFeedVideoIds = <String>{};
  bool _hasMoreFeedContent = true;
  bool _isPaginationRequestInFlight = false;

  HomeBloc() : super(HomeInitial()) {
    on<InitialEvent>(_onInitial);
    on<FetchFeedEvent>(_onFetchFeed);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
  }

  /// Handle InitialEvent - save user profile and fetch initial feed
  Future<void> _onInitial(InitialEvent event, Emitter<HomeState> emit) async {
    print('✓ HomeBloc InitialEvent triggered');

    try {
      await preferencesService.clearUserProfile();

      // Fetch user profile from Supabase
      final userProfile = await supabaseService.fetchUserPersonalProfile();

      if (userProfile != null) {
        // Save to preferences for offline access
        await preferencesService.saveUserProfile(userProfile);
        print('✓ User profile found and saved: ${userProfile.username}');
        emit(UserProfileLoaded(userProfile));

        // Automatically fetch initial feed after saving profile
        add(
          const FetchFeedEvent(
            limit: _homeFeedPageSize,
            offset: 0,
            forceRefresh: false,
          ),
        );
      } else {
        print('✗ No user profile found');
        emit(const NoUserProfile());
      }
    } catch (e) {
      print('✗ InitialEvent Error: $e');
      emit(FeedError(message: 'Failed to load user profile: $e'));
    }
  }

  /// Handle FetchFeedEvent - fetch blended home feed
  ///
  /// Fetches videos from 4 sources in parallel and blends them:
  /// - 40% Personalized (user's engaged categories)
  /// - 30% Following (videos from followed users)
  /// - 20% Trending (best-rated videos from last 7 days)
  /// - 10% Discovery (random from unwatched categories)
  Future<void> _onFetchFeed(
    FetchFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    print(
      '📺 HomeBloc FetchFeedEvent: limit=${event.limit}, offset=${event.offset}, forceRefresh=${event.forceRefresh}',
    );

    try {
      // Emit loading state
      final isFirstLoad = event.offset == 0;
      emit(FeedLoading(offset: event.offset, isFirstLoad: isFirstLoad));

      // Fetch blended feed from HomeFeedService
      final videos = await homeFeedService.getHomeFeed(
        limit: event.limit,

        offset: event.offset,
        forceRefresh: event.forceRefresh,
      );

      if (videos.isEmpty) {
        print('⚠️ No videos available');
        _hasMoreFeedContent = false;
        emit(
          FeedLoaded(
            videos: List<Map<String, dynamic>>.from(_allFeedVideos),
            offset: event.offset,
            hasMoreContent: false,
          ),
        );
        return;
      }

      final uniqueVideos = videos.where((video) {
        final videoId = video['id'] as String?;
        if (videoId == null) {
          return true;
        }

        return !_seenFeedVideoIds.contains(videoId);
      }).toList();

      // For pagination: append new videos to existing list if offset > 0
      if (event.offset == 0) {
        _allFeedVideos = uniqueVideos;
        _seenFeedVideoIds
          ..clear()
          ..addAll(
            uniqueVideos
                .map((video) => video['id'] as String?)
                .whereType<String>(),
          );
        _currentOffset = 0;
      } else {
        _allFeedVideos = [..._allFeedVideos, ...uniqueVideos];
        _seenFeedVideoIds.addAll(
          uniqueVideos
              .map((video) => video['id'] as String?)
              .whereType<String>(),
        );
      }

      print(
        '✓ Fetched ${videos.length} videos, ${uniqueVideos.length} unique, total feed size: ${_allFeedVideos.length}',
      );

      // Stop pagination once the backend returns a short page or no unseen videos.
      final hasMoreContent =
          videos.length >= event.limit && uniqueVideos.isNotEmpty;
      _hasMoreFeedContent = hasMoreContent;

      emit(
        FeedLoaded(
          videos: List<Map<String, dynamic>>.from(_allFeedVideos),
          offset: event.offset,
          hasMoreContent: hasMoreContent,
        ),
      );

      _currentOffset = event.offset + videos.length;
    } catch (e) {
      print('✗ FetchFeedEvent Error: $e');
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
  Future<void> _onRefreshFeed(
    RefreshFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    print('🔄 HomeBloc RefreshFeedEvent triggered');

    try {
      // Clear cache and reset pagination
      homeFeedService.clearCache();
      _currentOffset = 0;
      _allFeedVideos = [];
      _seenFeedVideoIds.clear();
      _hasMoreFeedContent = true;
      _isPaginationRequestInFlight = false;

      // Fetch fresh feed from top
      add(
        const FetchFeedEvent(
          limit: _homeFeedPageSize,
          offset: 0,
          forceRefresh: true,
        ),
      );
    } catch (e) {
      print('✗ RefreshFeedEvent Error: $e');
      emit(FeedError(message: 'Failed to refresh feed: $e'));
    }
  }

  /// Handle LoadMoreFeedEvent - load next page of feed
  ///
  /// Fetches next batch using current offset
  Future<void> _onLoadMoreFeed(
    LoadMoreFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    print(
      '⬇️ HomeBloc LoadMoreFeedEvent triggered, currentOffset=$_currentOffset',
    );

    try {
      if (!_hasMoreFeedContent) {
        print('⚠️ No more feed content available, ignoring load more');
        return;
      }

      if (_isPaginationRequestInFlight) {
        print(
          '⚠️ Pagination request already in flight, ignoring duplicate load more',
        );
        return;
      }

      _isPaginationRequestInFlight = true;

      // Fetch next batch at current offset
      add(
        FetchFeedEvent(
          limit: _homeFeedPageSize,
          offset: _currentOffset,
          forceRefresh: false,
        ),
      );
    } catch (e) {
      _isPaginationRequestInFlight = false;
      print('✗ LoadMoreFeedEvent Error: $e');
      emit(
        FeedError(
          message: 'Failed to load more videos: $e',
          offset: _currentOffset,
        ),
      );
    }
  }
}
