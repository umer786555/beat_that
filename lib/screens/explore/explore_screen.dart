import 'dart:async';

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

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _submittedQuery = '';
  final GlobalKey _revealKey = GlobalKey();
  int? _revealIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filterCatalog = context.select(
      (ExploreBloc bloc) => bloc.state.filterCatalog,
    );
    final selectedFilterId = context.select(
      (ExploreBloc bloc) => bloc.state.selectedFilterId,
    );

    Future<void> onRefresh() async {
      final exploreBloc = context.read<ExploreBloc>();
      final refreshCompletion = exploreBloc.stream.firstWhere(
        (state) => state is ExploreLoaded || state is ExploreError,
      );

      HapticFeedback.mediumImpact();
      exploreBloc.add(const RefreshExploreVideosEvent());
      await refreshCompletion;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchHeader(
              controller: _searchController,
              filterCatalog: filterCatalog,
              selectedFilterId: selectedFilterId,
              onChanged: _onQueryChanged,
              onFilterChanged: _onFilterChanged,
              onClearQuery: _clearSearchQuery,
            ),
            Expanded(
              child: BlocBuilder<ExploreBloc, ExploreState>(
                builder: (context, state) {
                  if (state is ExploreInitial) {
                    return ExploreEmptyState(isDark: isDark);
                  }

                  if (state is ExploreLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is ExploreError) {
                    return _buildRefreshableBody(
                      onRefresh: onRefresh,
                      child: ExploreErrorState(
                        message: state.message,
                        onRetry: () {
                          context.read<ExploreBloc>().add(
                            const RetryExploreSearchEvent(),
                          );
                        },
                      ),
                    );
                  }

                  final loadedState = state as ExploreLoaded;
                  if (loadedState.videos.isEmpty) {
                    if (loadedState.isRandomFeed) {
                      return _buildRefreshableBody(
                        onRefresh: onRefresh,
                        child: ExploreEmptyState(
                          isDark: isDark,
                          title: 'No Videos Yet',
                          description:
                              'There are no public videos to explore right now.',
                          icon: Icons.video_library_outlined,
                        ),
                      );
                    }

                    return _buildRefreshableBody(
                      onRefresh: onRefresh,
                      child: NoResultsState(
                        query: loadedState.query,
                        selectedFilterLabel:
                            loadedState.selectedFilterId == null
                            ? null
                            : loadedState.filterCatalog.labelFor(
                                loadedState.selectedFilterId,
                              ),
                      ),
                    );
                  }

                  final selectedFilterLabel = loadedState.filterCatalog
                      .labelFor(loadedState.selectedFilterId);
                  final filterLabel = loadedState.selectedFilterId == null
                      ? loadedState.query
                      : loadedState.query.isEmpty
                      ? selectedFilterLabel
                      : '${loadedState.query} in $selectedFilterLabel';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!loadedState.isRandomFeed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            '${loadedState.totalCount} result${loadedState.totalCount == 1 ? '' : 's'} for "$filterLabel"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: onRefresh,
                          child: _buildExploreGrid(loadedState: loadedState),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreGrid({required ExploreLoaded loadedState}) {
    final sections = _buildFeedSections(loadedState.videos);

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (
          var sectionIndex = 0;
          sectionIndex < sections.length;
          sectionIndex++
        ) ...[
          _buildVideoSectionSliver(
            sections[sectionIndex],
            loadedState: loadedState,
          ),
          if (sections[sectionIndex].showsAdAfter)
            SliverToBoxAdapter(
              child: ExploreFeedNativeAdCard(slotIndex: sectionIndex),
            ),
        ],
        if (loadedState.isLoadingMore)
          const FeedGridSkeletonSliver(
            itemCount: 2,
            padding: EdgeInsets.fromLTRB(
              kFeedGridSpacing,
              12,
              kFeedGridSpacing,
              0,
            ),
          ),
        if (loadedState.loadMoreFailed) _buildLoadMoreRetrySliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  SliverToBoxAdapter _buildLoadMoreRetrySliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Text(
              "Couldn't load more videos.",
              style: TextStyle(color: Colors.grey[600]),
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

  SliverPadding _buildVideoSectionSliver(
    _ExploreFeedSection section, {
    required ExploreLoaded loadedState,
  }) {
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
            key: globalIndex == _revealIndex ? _revealKey : null,
            videoId: video.id,
            thumbnailUrl: video.thumbnailUrl ?? '',
            title: video.title,
            username: video.username,
            sportId: video.sportId,
            viewCount: video.viewCount,
            rating: video.averageRating,
            onTap: () async {
              HapticFeedback.mediumImpact();
              final exploreBloc = context.read<ExploreBloc>();
              final progressStore = locator<ExploreFeedProgressStore>()
                ..clear();

              await context.pushNamed(
                'explore-video-feed',
                extra: ExploreVideoFeedExtra(
                  videos: List.of(loadedState.videos),
                  initialIndex: globalIndex,
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
            },
            onUsernameTap: () {
              final userId = video.userId;
              if (userId.isEmpty) {
                return;
              }

              context.pushNamed(
                'creator-profile',
                extra: CreatorProfileExtra(userId: userId),
              );
            },
          );
        }, childCount: section.videos.length),
      ),
    );
  }

  void _revealVideo(int index, ExploreBloc exploreBloc) {
    if (!mounted) return;
    setState(() => _revealIndex = index);
    revealFeedGridItem(
      controller: _scrollController,
      targetKey: _revealKey,
      estimatedOffset: estimateFeedGridOffset(
        index: index,
        gridWidth: MediaQuery.sizeOf(context).width,
      ),
      // Stop if the merge was skipped and the grid doesn't contain this video.
      shouldContinue: () {
        final state = exploreBloc.state;
        return mounted && state is ExploreLoaded && index < state.videos.length;
      },
    );
  }

  List<_ExploreFeedSection> _buildFeedSections(List<dynamic> videos) {
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

  Widget _buildRefreshableBody({
    required Widget child,
    required RefreshCallback onRefresh,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ),
        );
      },
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
  final List<dynamic> videos;
  final bool showsAdAfter;
}
