import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:beat_that/widgets/shimmer_loading.dart';

/// Home screen displayed when user is logged in
/// Shows personalized video feed with YouTube/Instagram-style layout
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  static const double _scrollTriggerDistance = 500;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll events for infinite scroll pagination
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final triggerDistance = maxScroll - _scrollTriggerDistance;

    // Trigger load more when user is 500px from bottom
    if (currentScroll >= triggerDistance) {
      context.read<HomeBloc>().add(const LoadMoreFeedEvent());
    }
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    context.read<HomeBloc>().add(const RefreshFeedEvent());
    // Wait for the refresh to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        /// Listener: Handle navigation and side effects
        listener: (context, state) {
          if (state is NoUserProfile) {
            // Navigate to username setup screen
            context.go('/username-setup');
          }
        },

        /// Builder: Render UI based on state
        builder: (context, state) {
          // Initial state - not ready yet
          if (state is HomeInitial) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // No user profile state
          if (state is NoUserProfile) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profile not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please set up your profile to continue',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Loading state (first load or pagination)
          if (state is FeedLoading) {
            if (state.isFirstLoad) {
              // First load - show full shimmer
              return ShimmerLoading(cardCount: 8);
            } else {
              // Pagination - this state shouldn't show, but handle gracefully
              return _buildFeedGrid([], isLoading: true);
            }
          }

          // Error state
          if (state is FeedError) {
            return _buildErrorState(state.message);
          }

          // Loaded state - show feed
          if (state is FeedLoaded) {
            if (state.videos.isEmpty && state.offset == 0) {
              return _buildEmptyState();
            }

            return _buildFeedGrid(
              state.videos,
              hasMoreContent: state.hasMoreContent,
              isLoading: false,
            );
          }

          // Fallback
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build the main feed grid with videos and pull-to-refresh
  Widget _buildFeedGrid(
    List<dynamic> videos, {
    bool hasMoreContent = true,
    bool isLoading = false,
  }) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Stack(
        children: [
          /// Main grid
          GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 9 / 14,
            ),
            itemCount: videos.length + (isLoading ? 2 : 0),
            itemBuilder: (context, index) {
              // Show shimmer cards at bottom during pagination
              if (index >= videos.length) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[300],
                    ),
                  ),
                );
              }

              final video = videos[index];
              return VideoFeedCard(
                videoId: video['id'] ?? '',
                thumbnailUrl: video['thumbnail_url'] ?? '',
                username: video['username'] ?? 'Unknown',
                viewCount: (video['view_count'] as num?)?.toInt() ?? 0,
                rating: (video['average_rating'] as num?)?.toDouble() ?? 0.0,
                sourceType: video['source'] ?? 'discovery',
                onTap: () {
                  // TODO: Navigate to video player screen
                  print('Tapped video: ${video['id']}');
                },
                onLongPress: () {
                  // TODO: Show context menu (share, report, etc.)
                  print('Long pressed video: ${video['id']}');
                },
              );
            },
          ),

          /// Loading indicator at bottom
          if (isLoading && videos.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ShimmerLoadingIndicator(),
            ),
        ],
      ),
    );
  }

  /// Build error state UI
  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Failed to load videos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () {
              context.read<HomeBloc>().add(const RefreshFeedEvent());
            },
          ),
        ],
      ),
    );
  }

  /// Build empty state UI (no videos available)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No videos yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Follow users or explore categories\nto see videos here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.explore),
            label: const Text('Explore'),
            onPressed: () {
              // TODO: Navigate to explore/discovery screen
              context.go('/explore');
            },
          ),
        ],
      ),
    );
  }
}
