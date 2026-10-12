import 'dart:async';

import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_route_extra.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/explore_empty_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/explore_error_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/no_results_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/search_header.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/widgets/explore_feed_native_ad_card.dart';
import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:beat_that/widgets/feed_grid_reveal.dart';
import 'package:beat_that/widgets/feed_grid_skeleton_sliver.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;

    return BlocProvider(
      create: (context) => ExploreBloc(locale: platformLocale)
        ..add(const LoadExploreFiltersEvent())
        ..add(const SearchExploreVideosEvent(query: '')),
      child: const _ExploreView(),
    );
  }
}

class _ExploreView extends StatefulWidget {
  const _ExploreView();

  @override
  State<_ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<_ExploreView> {
  static const Duration _searchDebounce = Duration(milliseconds: 500);
  static const double _loadMoreThreshold = 360;
  static const int _firstAdInsertionIndex = 4;
  static const int _subsequentAdInsertionInterval = 8;

  /// Header height used until the first post-frame measurement.
  static const double _fallbackHeaderExtent = 58;

  /// Approximate height of the results line shown above search results.
  static const double _resultsLineExtent = 40;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _submittedQuery = '';
  final GlobalKey _revealKey = GlobalKey();
  int? _revealIndex;
  final GlobalKey _headerKey = GlobalKey();
  double _headerExtent = _fallbackHeaderExtent;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _scheduleHeaderMeasurement();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.maxScrollExtent <= 0) {
      return;
    }

    final remainingDistance =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    if (remainingDistance <= _loadMoreThreshold) {
      context.read<ExploreBloc>().add(const LoadMoreExploreVideosEvent());
    }
  }

  /// Re-reads the header height after layout; it grows when search opens.
  void _scheduleHeaderMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _headerKey.currentContext?.size?.height;
      if (height == null || (height - _headerExtent).abs() <= 0.5) return;
      setState(() => _headerExtent = height);
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients && _scrollController.position.pixels > 0) {
      _scrollController.jumpTo(0);
    }
  }

  void _onQueryChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    _debounce?.cancel();
    final query = ExploreBloc.effectiveQuery(value);
    if (query == _submittedQuery) {
      return;
    }

    final selectedFilterId = context.read<ExploreBloc>().state.selectedFilterId;

    if (query.isEmpty) {
      _submitQuery('', selectedFilterId);
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }

      _submitQuery(query, selectedFilterId);
    });
  }

  void _submitQuery(String query, String? selectedFilterId) {
    _submittedQuery = query;
    context.read<ExploreBloc>().add(
      SearchExploreVideosEvent(
        query: query,
        selectedFilterId: selectedFilterId,
      ),
    );
  }

  void _onFilterChanged(String? filterId) {
    final selectedFilterId = context.read<ExploreBloc>().state.selectedFilterId;
    if (selectedFilterId == filterId) {
      return;
    }

    _debounce?.cancel();
    _submitQuery(ExploreBloc.effectiveQuery(_searchController.text), filterId);
  }

  void _clearSearchQuery() {
    _debounce?.cancel();
    _searchController.clear();
    if (_submittedQuery.isEmpty) {
      return;
    }

    _submitQuery('', context.read<ExploreBloc>().state.selectedFilterId);
  }

  Future<void> _onRefresh() async {
    final exploreBloc = context.read<ExploreBloc>();
    final refreshCompletion = exploreBloc.stream.firstWhere(
      (state) => state is ExploreLoaded || state is ExploreError,
    );

    HapticFeedback.mediumImpact();
    exploreBloc.add(const RefreshExploreVideosEvent());
    await refreshCompletion;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: BlocListener<ExploreBloc, ExploreState>(
          listenWhen: (_, state) => state is ExploreLoading,
          listener: (_, _) => _scrollToTop(),
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            edgeOffset: _headerExtent,
            child: BlocBuilder<ExploreBloc, ExploreState>(
              builder: (context, state) {
                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverFloatingHeader(
                      child:
                          NotificationListener<SizeChangedLayoutNotification>(
                            onNotification: (_) {
                              _scheduleHeaderMeasurement();
                              return true;
                            },
                            child: SizeChangedLayoutNotifier(
                              child: ColoredBox(
                                color: theme.scaffoldBackgroundColor,
                                child: SearchHeader(
                                  key: _headerKey,
                                  controller: _searchController,
                                  filterCatalog: state.filterCatalog,
                                  selectedFilterId: state.selectedFilterId,
                                  onChanged: _onQueryChanged,
                                  onFilterChanged: _onFilterChanged,
                                  onClearQuery: _clearSearchQuery,
                                ),
                              ),
                            ),
                          ),
                    ),
                    ..._buildStateSlivers(state, isDark: isDark),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStateSlivers(ExploreState state, {required bool isDark}) {
    switch (state) {
      case ExploreInitial() || ExploreLoading():
        return const [FeedGridSkeletonSliver(itemCount: 8)];
      case ExploreError():
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ExploreErrorState(
              message: state.message,
              onRetry: () => context.read<ExploreBloc>().add(
                const RetryExploreSearchEvent(),
              ),
            ),
          ),
        ];
      case ExploreLoaded(videos: []):
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: state.isRandomFeed
                ? ExploreEmptyState(
                    isDark: isDark,
                    title: 'No Videos Yet',
                    description:
                        'There are no public videos to explore right now.',
                    icon: Icons.video_library_outlined,
                  )
                : NoResultsState(
                    query: state.query,
                    selectedFilterLabel: state.selectedFilterId == null
                        ? null
                        : state.filterCatalog.labelFor(state.selectedFilterId),
                  ),
          ),
        ];
      case ExploreLoaded():
        final sections = _buildFeedSections(state.videos);
        return [
          if (!state.isRandomFeed) _ResultsCountSliver(state: state),
          for (
            var sectionIndex = 0;
            sectionIndex < sections.length;
            sectionIndex++
          ) ...[
            _VideoSectionSliver(
              section: sections[sectionIndex],
              revealIndex: _revealIndex,
              revealKey: _revealKey,
              onVideoTap: (index) => _openVideoFeed(state, index),
              onUsernameTap: _openCreatorProfile,
            ),
            if (sections[sectionIndex].showsAdAfter)
              SliverToBoxAdapter(
                child: ExploreFeedNativeAdCard(slotIndex: sectionIndex),
              ),
          ],
          if (state.isLoadingMore)
            const FeedGridSkeletonSliver(
              itemCount: 2,
              padding: EdgeInsets.fromLTRB(
                kFeedGridSpacing,
                12,
                kFeedGridSpacing,
                0,
              ),
            ),
          if (state.loadMoreFailed) const _LoadMoreRetrySliver(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ];
    }
  }

  Future<void> _openVideoFeed(ExploreLoaded loadedState, int index) async {
    HapticFeedback.mediumImpact();
    // Otherwise focus returns to the search field on pop and pulls the
    // header back into view while the grid reveal runs.
    FocusManager.instance.primaryFocus?.unfocus();
    final exploreBloc = context.read<ExploreBloc>();
    final progressStore = locator<ExploreFeedProgressStore>()..clear();

    await context.pushNamed(
      'explore-video-feed',
      extra: ExploreVideoFeedExtra(
        videos: List.of(loadedState.videos),
        initialIndex: index,
        query: loadedState.query,
        selectedSportId: loadedState.selectedFilterId,
        nextOffset: loadedState.nextOffset,
        hasMoreContent: loadedState.hasMore,
        isRandomFeed: loadedState.isRandomFeed,
        randomSeed: loadedState.randomSeed,
        randomAfterId: loadedState.randomAfterId,
        randomHasWrapped: loadedState.randomHasWrapped,
      ),
    );

    final progress = progressStore.take();
    if (progress != null && !exploreBloc.isClosed) {
      exploreBloc.add(MergeExploreFeedProgressEvent(progress));
      _revealVideo(progress.currentIndex, exploreBloc);
    }
  }

  void _openCreatorProfile(SportVideo video) {
    final userId = video.userId;
    if (userId.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    context.pushNamed(
      'creator-profile',
      extra: CreatorProfileExtra(userId: userId),
    );
  }

  void _revealVideo(int index, ExploreBloc exploreBloc) {
    if (!mounted) return;
    setState(() => _revealIndex = index);
    final state = exploreBloc.state;
    final showsResultsLine = state is ExploreLoaded && !state.isRandomFeed;
    revealFeedGridItem(
      controller: _scrollController,
      targetKey: _revealKey,
      estimatedOffset: estimateFeedGridOffset(
        index: index,
        gridWidth: MediaQuery.sizeOf(context).width,
        headerOffset:
            _headerExtent + (showsResultsLine ? _resultsLineExtent : 0),
      ),
      // Stop if the merge was skipped and the grid doesn't contain this video.
      shouldContinue: () {
        final state = exploreBloc.state;
        return mounted && state is ExploreLoaded && index < state.videos.length;
      },
    );
  }

  List<_ExploreFeedSection> _buildFeedSections(List<SportVideo> videos) {
    final sections = <_ExploreFeedSection>[];
    var start = 0;
    var nextChunkLength = _firstAdInsertionIndex;

    while (start < videos.length) {
      final end = (start + nextChunkLength < videos.length)
          ? start + nextChunkLength
          : videos.length;

      sections.add(
        _ExploreFeedSection(
          startVideoIndex: start,
          videos: videos.sublist(start, end),
          showsAdAfter: end < videos.length,
        ),
      );

      start = end;
      nextChunkLength = _subsequentAdInsertionInterval;
    }

    return sections;
  }
}

class _ResultsCountSliver extends StatelessWidget {
  const _ResultsCountSliver({required this.state});

  final ExploreLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedFilterLabel = state.filterCatalog.labelFor(
      state.selectedFilterId,
    );
    final filterLabel = state.selectedFilterId == null
        ? state.query
        : state.query.isEmpty
        ? selectedFilterLabel
        : '${state.query} in $selectedFilterLabel';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          '${state.totalCount} result${state.totalCount == 1 ? '' : 's'} for "$filterLabel"',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VideoSectionSliver extends StatelessWidget {
  const _VideoSectionSliver({
    required this.section,
    required this.revealIndex,
    required this.revealKey,
    required this.onVideoTap,
    required this.onUsernameTap,
  });

  final _ExploreFeedSection section;
  final int? revealIndex;
  final GlobalKey revealKey;
  final ValueChanged<int> onVideoTap;
  final ValueChanged<SportVideo> onUsernameTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        kFeedGridSpacing,
        section.startVideoIndex == 0 ? kFeedGridSpacing : 0,
        kFeedGridSpacing,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: kFeedGridDelegate,
        delegate: SliverChildBuilderDelegate((context, localIndex) {
          final globalIndex = section.startVideoIndex + localIndex;
          final video = section.videos[localIndex];
          return VideoFeedCard(
            key: globalIndex == revealIndex ? revealKey : null,
            videoId: video.id,
            thumbnailUrl: video.thumbnailUrl ?? '',
            title: video.title,
            username: video.username,
            sportId: video.sportId,
            viewCount: video.viewCount,
            rating: video.averageRating,
            onTap: () => onVideoTap(globalIndex),
            onUsernameTap: () => onUsernameTap(video),
          );
        }, childCount: section.videos.length),
      ),
    );
  }
}

class _LoadMoreRetrySliver extends StatelessWidget {
  const _LoadMoreRetrySliver();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Text(
              "Couldn't load more videos.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.read<ExploreBloc>().add(
                const LoadMoreExploreVideosEvent(isRetry: true),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreFeedSection {
  const _ExploreFeedSection({
    required this.startVideoIndex,
    required this.videos,
    required this.showsAdAfter,
  });

  final int startVideoIndex;
  final List<SportVideo> videos;
  final bool showsAdAfter;
}
