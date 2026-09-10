import 'dart:async';

import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_route_extra.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/explore_empty_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/explore_error_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/no_results_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/search_header.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/search_loading_card.dart';
import 'package:beat_that/widgets/explore_feed_native_ad_card.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExploreBloc(),
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
  static const Duration _searchDebounce = Duration(milliseconds: 350);
  static const double _loadMoreThreshold = 360;
  static const int _firstAdInsertionIndex = 4;
  static const int _subsequentAdInsertionInterval = 8;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String? _selectedSportId;

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

    if (value.trim().isEmpty) {
      context.read<ExploreBloc>().add(
        SearchExploreVideosEvent(query: '', selectedSportId: _selectedSportId),
      );
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }

      context.read<ExploreBloc>().add(
        SearchExploreVideosEvent(
          query: value,
          selectedSportId: _selectedSportId,
        ),
      );
    });
  }

  void _onSportChanged(String? sportId) {
    if (_selectedSportId == sportId) {
      return;
    }

    setState(() {
      _selectedSportId = sportId;
    });

    _debounce?.cancel();
    context.read<ExploreBloc>().add(
      SearchExploreVideosEvent(
        query: _searchController.text,
        selectedSportId: _selectedSportId,
      ),
    );
  }

  void _clearSearchQuery() {
    _debounce?.cancel();
    _searchController.clear();
    context.read<ExploreBloc>().add(
      SearchExploreVideosEvent(query: '', selectedSportId: _selectedSportId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final availableSportIds = getOrderedSportIdsForLocale(platformLocale);

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
              selectedSportId: _selectedSportId,
              availableSportIds: availableSportIds,
              onChanged: _onQueryChanged,
              onSportChanged: _onSportChanged,
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
                    return _buildRefreshableBody(
                      onRefresh: onRefresh,
                      child: NoResultsState(
                        query: loadedState.query,
                        selectedSportId: loadedState.selectedSportId,
                      ),
                    );
                  }

                  final filterLabel = loadedState.selectedSportId == null
                      ? loadedState.query
                      : loadedState.query.isEmpty
                      ? getDisplayNameForSport(loadedState.selectedSportId!)
                      : '${loadedState.query} in ${getDisplayNameForSport(loadedState.selectedSportId!)}';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          child: _buildExploreGrid(
                            loadedState: loadedState,
                            isDark: isDark,
                          ),
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

  Widget _buildExploreGrid({
    required ExploreLoaded loadedState,
    required bool isDark,
  }) {
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
        if (loadedState.isLoadingMore) _buildLoadingSliver(isDark: isDark),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  SliverPadding _buildVideoSectionSliver(
    _ExploreFeedSection section, {
    required ExploreLoaded loadedState,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        6,
        section.startVideoIndex == 0 ? 6 : 0,
        6,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.64,
        ),
        delegate: SliverChildBuilderDelegate((context, localIndex) {
          final globalIndex = section.startVideoIndex + localIndex;
          final video = section.videos[localIndex];
          return VideoFeedCard(
            videoId: video.id,
            thumbnailUrl: video.thumbnailUrl ?? '',
            title: video.title,
            username: video.username,
            sportId: video.sportId,
            viewCount: video.viewCount,
            rating: video.averageRating,
            onTap: () {
              HapticFeedback.mediumImpact();

              context.pushNamed(
                'explore-video-feed',
                extra: ExploreVideoFeedExtra(
                  videos: List.of(loadedState.videos),
                  initialIndex: globalIndex,
                  query: loadedState.query,
                  selectedSportId: loadedState.selectedSportId,
                  nextOffset: loadedState.nextOffset,
                  hasMoreContent: loadedState.hasMore,
                ),
              );
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

  SliverPadding _buildLoadingSliver({required bool isDark}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.64,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return SearchLoadingCard(isDark: isDark);
        }, childCount: 2),
      ),
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
