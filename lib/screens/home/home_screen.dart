import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/screens/home/video_feed/models/home_video_feed_route_extra.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:beat_that/widgets/feed_grid_reveal.dart';
import 'package:beat_that/widgets/feed_grid_skeleton_sliver.dart';
import 'package:beat_that/widgets/home_feed_native_ad_card.dart';
import 'package:beat_that/widgets/video_feed_card.dart';

/// Home screen displayed when user is logged in
/// Shows personalized video feed
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _homeOnboardingVersion = 1;
  static const int _firstAdInsertionIndex = 4;
  static const int _subsequentAdInsertionInterval = 8;
  late ScrollController _scrollController;
  static const double _scrollTriggerDistance = 500;
  final OnboardingService _onboardingService = locator<OnboardingService>();
  final GlobalKey _firstVideoCardOnboardingKey = GlobalKey();
  bool _hasAttemptedHomeOnboarding = false;
  final GlobalKey _revealKey = GlobalKey();
  int? _revealIndex;

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
    if (maxScroll <= 0) return;

    final triggerDistance = maxScroll - _scrollTriggerDistance;

    // Trigger load more when user is 500px from bottom
    if (currentScroll >= triggerDistance) {
      context.read<HomeBloc>().add(const LoadMoreFeedEvent());
    }
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    final homeBloc = context.read<HomeBloc>();
    final refreshCompletion = homeBloc.stream.firstWhere(
      (state) =>
          (state is FeedLoaded && !state.isLoadingMore) ||
          state is FeedError ||
          state is NoUserProfile,
    );

    HapticFeedback.mediumImpact();
    homeBloc.add(const RefreshFeedEvent());
    await refreshCompletion;
  }

  Future<void> _maybePresentHomeOnboarding(List<SportVideo> videos) async {
    if (_hasAttemptedHomeOnboarding || !mounted) {
      return;
    }

    _hasAttemptedHomeOnboarding = true;

    await _onboardingService.startFlow(
      context,
      OnboardingFlowRequest(
        flowId: OnboardingFlowIds.homeFeed,
        version: _homeOnboardingVersion,
        steps: videos.isEmpty
            ? const <OnboardingStepData>[]
            : <OnboardingStepData>[
                OnboardingStepData(
                  key: _firstVideoCardOnboardingKey,
                  title: 'Open your feed',
                  description:
                      'Tap any clip to jump into the full feed. Home will learn from what you watch and show you more of it here.',
                ),
              ],
      ),
      beforeStart: _showHomeOnboardingIntro,
    );
  }

  Future<bool> _showHomeOnboardingIntro(BuildContext context) async {
    return showAppOnboardingIntroSheet(
      context,
      icon: Icons.ondemand_video_rounded,
      title: 'This is your Home feed',
      description:
          'Home is where Beat That will surface clips based on what you watch, who you follow, and the sports you engage with.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Home',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        /// Listener: Handle navigation and side effects
        listener: (context, state) {
          if (state is NoUserProfile) {
            // Navigate to username setup screen
            context.go('/username-setup');
          }

          if (state is FeedLoaded &&
              state.offset == 0 &&
              !state.isLoadingMore) {
            _maybePresentHomeOnboarding(state.videos);
          }
        },

        /// Builder: Render UI based on state
        builder: (context, state) {
          // Initial state or first-page load - show full shimmer
          if (state is HomeInitial || state is FeedLoading) {
            return const _FirstLoadSkeleton();
          }

          // No user profile state
          if (state is NoUserProfile) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
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

          // Error state
          if (state is FeedError) {
            return _buildRefreshableBody(
              child: _buildErrorState(state.message),
            );
          }

          // Loaded state - show feed
          if (state is FeedLoaded) {
            if (state.videos.isEmpty && state.offset == 0) {
              return _buildRefreshableBody(child: _buildEmptyState());
            }

            return _buildFeedGrid(
              state.videos,
              hasMoreContent: state.hasMoreContent,
              nextCursor: state.nextCursor,
              isLoading: state.isLoadingMore,
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
    List<SportVideo> videos, {
    bool hasMoreContent = true,
    HomeFeedCursor nextCursor = const HomeFeedCursor.initial(),
    bool isLoading = false,
  }) {
    final sections = _buildFeedSections(videos);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
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
              allVideos: videos,
              hasMoreContent: hasMoreContent,
              nextCursor: nextCursor,
            ),
            if (sections[sectionIndex].showsAdAfter)
              SliverToBoxAdapter(
                child: HomeFeedNativeAdCard(slotIndex: sectionIndex),
              ),
          ],
          if (isLoading && videos.isNotEmpty)
            const FeedGridSkeletonSliver(
              itemCount: 2,
              padding: kFeedGridLoadMorePadding,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  SliverPadding _buildVideoSectionSliver(
    _HomeFeedSection section, {
    required List<SportVideo> allVideos,
    required bool hasMoreContent,
    required HomeFeedCursor nextCursor,
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
          final card = VideoFeedCard(
            key: globalIndex == _revealIndex ? _revealKey : null,
            videoId: video.id,
            thumbnailUrl: video.thumbnailUrl ?? '',
            title: video.title,
            username: video.username ?? '',
            sportId: video.sportId,
            viewCount: video.viewCount,
            rating: video.averageRating,
            onTap: () async {
              final homeBloc = context.read<HomeBloc>();
              final sessionStore = locator<HomeVideoFeedSessionStore>();
              final sessionId = sessionStore.createSession(
                videos: List.of(allVideos),
                nextCursor: nextCursor,
                hasMoreContent: hasMoreContent,
                initialIndex: globalIndex,
              );

              await context.pushNamed(
                'home-video-feed',
                extra: HomeVideoFeedExtra(
                  sessionId: sessionId,
                  initialIndex: globalIndex,
                ),
              );

              final session = sessionStore.takeSession(sessionId);
              if (session == null || homeBloc.isClosed) return;

              homeBloc.add(
                MergeVideoFeedSessionEvent(
                  videos: List.of(session.videos),
                  nextCursor: session.nextCursor,
                  hasMoreContent: session.hasMoreContent,
                ),
              );
              _revealVideo(session.currentIndex, homeBloc);
            },
          );

          if (globalIndex == 0) {
            return AppOnboardingTarget(
              targetKey: _firstVideoCardOnboardingKey,
              title: 'Open your feed',
              description:
                  'Tap any clip to jump into the full feed. Home learns from what you watch and uses that to improve recommendations.',
              child: card,
            );
          }

          return card;
        }, childCount: section.videos.length),
      ),
    );
  }

  void _revealVideo(int index, HomeBloc homeBloc) {
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
        final state = homeBloc.state;
        return mounted &&
            state is FeedLoaded &&
            !state.isLoadingMore &&
            index < state.videos.length;
      },
    );
  }

  List<_HomeFeedSection> _buildFeedSections(List<SportVideo> videos) {
    final sections = <_HomeFeedSection>[];
    var start = 0;
    var nextChunkLength = _firstAdInsertionIndex;

    while (start < videos.length) {
      final end = (start + nextChunkLength < videos.length)
          ? start + nextChunkLength
          : videos.length;

      sections.add(
        _HomeFeedSection(
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

  Widget _buildRefreshableBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
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

  /// Build error state UI
  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () {
              HapticFeedback.mediumImpact();
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
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text('No videos yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your Home feed will learn from what you watch\nand who you follow. Explore a few clips to start shaping it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.explore),
            label: const Text('Explore'),
            onPressed: () {
              HapticFeedback.mediumImpact();
              // TODO: Navigate to explore/discovery screen
              context.go('/explore');
            },
          ),
        ],
      ),
    );
  }
}

class _FirstLoadSkeleton extends StatelessWidget {
  const _FirstLoadSkeleton();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: [FeedGridSkeletonSliver(itemCount: 8)],
    );
  }
}

class _HomeFeedSection {
  const _HomeFeedSection({
    required this.startVideoIndex,
    required this.videos,
    required this.showsAdAfter,
  });

  final int startVideoIndex;
  final List<SportVideo> videos;
  final bool showsAdAfter;
}
