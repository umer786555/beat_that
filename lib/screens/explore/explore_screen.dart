import 'dart:async';

import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_route_extra.dart';
import 'package:beat_that/widgets/form_input_decoration.dart';
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

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String? _selectedSportId;

  static final List<String> _availableSportIds = List<String>.from(
    sportOrderByLocale['en'] ?? const <String>[],
  );

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
        SearchExploreVideosEvent(
          query: '',
          searchMode: ExploreSearchMode.soft,
          selectedSportId: _selectedSportId,
        ),
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
          searchMode: ExploreSearchMode.soft,
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
        searchMode: ExploreSearchMode.soft,
        selectedSportId: _selectedSportId,
      ),
    );
  }

  void _clearAllFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _selectedSportId = null;
    });
    context.read<ExploreBloc>().add(
      SearchExploreVideosEvent(
        query: '',
        searchMode: ExploreSearchMode.soft,
        selectedSportId: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onRefresh = () async {
      final exploreBloc = context.read<ExploreBloc>();
      final refreshCompletion = exploreBloc.stream.firstWhere(
        (state) => state is ExploreLoaded || state is ExploreError,
      );

      HapticFeedback.mediumImpact();
      exploreBloc.add(const RefreshExploreVideosEvent());
      await refreshCompletion;
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              selectedSportId: _selectedSportId,
              availableSportIds: _availableSportIds,
              onChanged: _onQueryChanged,
              onSportChanged: _onSportChanged,
              onClear: _clearAllFilters,
            ),
            Expanded(
              child: BlocBuilder<ExploreBloc, ExploreState>(
                builder: (context, state) {
                  if (state is ExploreInitial) {
                    return _ExploreEmptyState(isDark: isDark);
                  }

                  if (state is ExploreLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is ExploreError) {
                    return _buildRefreshableBody(
                      onRefresh: onRefresh,
                      child: _ExploreErrorState(
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
                      child: _NoResultsState(
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
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.64,
                                ),
                            itemCount:
                                loadedState.videos.length +
                                (loadedState.isLoadingMore ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (index >= loadedState.videos.length) {
                                return _SearchLoadingCard(isDark: isDark);
                              }

                              final video = loadedState.videos[index];
                              return VideoFeedCard(
                                videoId: video['id'] ?? '',
                                thumbnailUrl: video['thumbnail_url'] ?? '',
                                title: video['title'] as String?,
                                username: video['username'] as String?,
                                sportId: video['sport_id'] as String?,
                                viewCount:
                                    (video['view_count'] as num?)?.toInt() ?? 0,
                                rating:
                                    (video['average_rating'] as num?)?.toDouble() ?? 0.0,
                                onTap: () {
                                  HapticFeedback.mediumImpact();

                                  final initialVideos = loadedState.videos
                                      .map(
                                        (item) =>
                                            Map<String, dynamic>.from(item),
                                      )
                                      .toList();

                                  context.pushNamed(
                                    'explore-video-feed',
                                    extra: ExploreVideoFeedExtra(
                                      videos: initialVideos,
                                      initialIndex: index,
                                      query: loadedState.query,
                                      searchMode: loadedState.searchMode,
                                      selectedSportId:
                                          loadedState.selectedSportId,
                                      nextOffset: loadedState.nextOffset,
                                      hasMoreContent: loadedState.hasMore,
                                    ),
                                  );
                                },
                                onUsernameTap: () {
                                  final userId = video['user_id'] as String?;
                                  if (userId == null || userId.isEmpty) {
                                    return;
                                  }

                                  context.pushNamed(
                                    'creator-profile',
                                    extra: CreatorProfileExtra(userId: userId),
                                  );
                                },
                              );
                            },
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

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.selectedSportId,
    required this.availableSportIds,
    required this.onChanged,
    required this.onSportChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String? selectedSportId;
  final List<String> availableSportIds;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onSportChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            cursorColor: AppColors.cyan,
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search videos by title',
              labelText: 'Search',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SportChip(
                    label: 'All Sports',
                    selected: selectedSportId == null,
                    onSelected: () => onSportChanged(null),
                  ),
                  ...availableSportIds.map(
                    (sportId) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _SportChip(
                        label: getDisplayNameForSport(sportId),
                        selected: selectedSportId == sportId,
                        onSelected: () => onSportChanged(sportId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: isDark
          ? AppColors.cyan.withOpacity(0.88)
          : AppColors.electricMagenta.withOpacity(0.88),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (isDark ? Colors.white24 : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ExploreEmptyState extends StatelessWidget {
  const _ExploreEmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.cyan.withOpacity(0.14)
                    : AppColors.electricMagenta.withOpacity(0.10),
              ),
              child: Icon(
                Icons.search_rounded,
                color: isDark ? AppColors.cyan : AppColors.electricMagenta,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Search Videos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Type a title or pick a sport to search for linked videos and see the results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreErrorState extends StatelessWidget {
  const _ExploreErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query, this.selectedSportId});

  final String query;
  final String? selectedSportId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              selectedSportId == null
                  ? 'No videos found for "$query"'
                  : query.isEmpty
                  ? 'No videos found in ${getDisplayNameForSport(selectedSportId!)}'
                  : 'No videos found for "$query" in ${getDisplayNameForSport(selectedSportId!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a shorter phrase, a different title, or a different sport filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLoadingCard extends StatelessWidget {
  const _SearchLoadingCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white10 : Colors.black12,
      ),
    );
  }
}
