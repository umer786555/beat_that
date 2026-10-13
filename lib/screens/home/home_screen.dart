import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/screens/home/video_feed/models/home_video_feed_route_extra.dart';
import 'package:beat_that/screens/home/widgets/home_feed_message.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:beat_that/widgets/feed_grid_reveal.dart';
import 'package:beat_that/widgets/feed_grid_skeleton_sliver.dart';
import 'package:beat_that/widgets/home_feed_native_ad_card.dart';
import 'package:beat_that/widgets/video_feed_card.dart';

const int _firstAdInsertionIndex = 4;
const int _subsequentAdInsertionInterval = 8;

/// Home screen displayed when user is logged in
/// Shows personalized video feed
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(const InitialEvent()),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const int _homeOnboardingVersion = 1;
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
                  title: AppStrings.homeOnboardingFirstVideoTitle,
                  description:
                      AppStrings.homeOnboardingFirstVideoStepDescription,
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
      title: AppStrings.homeOnboardingIntroTitle,
      description: AppStrings.homeOnboardingIntroDescription,
    );
  }

  Future<void> _openVideoFeed(FeedLoaded feed, int index) async {
    final homeBloc = context.read<HomeBloc>();
    final sessionStore = locator<HomeVideoFeedSessionStore>();
    final sessionId = sessionStore.createSession(
      videos: List.of(feed.videos),
      nextCursor: feed.nextCursor,
      hasMoreContent: feed.hasMoreContent,
      initialIndex: index,
    );

    await context.pushNamed(
      'home-video-feed',
      extra: HomeVideoFeedExtra(sessionId: sessionId, initialIndex: index),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          AppStrings.home,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is NoUserProfile) {
            context.go('/username-setup');
          }

          if (state is FeedLoaded &&
              state.offset == 0 &&
              !state.isLoadingMore) {
            _maybePresentHomeOnboarding(state.videos);
          }
        },
        builder: (context, state) => switch (state) {
          HomeInitial() || FeedLoading() => const _FirstLoadSkeleton(),
          NoUserProfile() => const _MissingProfileBody(),
          FeedError() => _RefreshableBody(
            onRefresh: _onRefresh,
            child: HomeFeedMessage(
              icon: Icons.error_outline,
              iconColor: Colors.red[300],
              title: AppStrings.homeFeedErrorTitle,
              message: AppStrings.somethingWentWrongPleaseTryAgain,
              actionIcon: Icons.refresh,
              actionLabel: AppStrings.retry,
              onAction: () =>
                  context.read<HomeBloc>().add(const RefreshFeedEvent()),
            ),
          ),
          FeedLoaded(videos: [], offset: 0) => _RefreshableBody(
            onRefresh: _onRefresh,
            child: HomeFeedMessage(
              icon: Icons.video_library_outlined,
              iconColor: Colors.grey[400],
              title: AppStrings.homeEmptyTitle,
              message: AppStrings.homeEmptyMessage,
              actionIcon: Icons.explore,
              actionLabel: AppStrings.explore,
              onAction: () => context.go('/explore'),
            ),
          ),
          FeedLoaded() => _HomeFeedGrid(
            feed: state,
            scrollController: _scrollController,
            onRefresh: _onRefresh,
            revealIndex: _revealIndex,
            revealKey: _revealKey,
            firstCardKey: _firstVideoCardOnboardingKey,
            onVideoTap: (index) => _openVideoFeed(state, index),
          ),
        },
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

class _MissingProfileBody extends StatelessWidget {
  const _MissingProfileBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppStrings.homeProfileNotFoundTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.homeProfileNotFoundMessage,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

/// Lets a non-scrolling body fill the viewport and still pull to refresh.
class _RefreshableBody extends StatelessWidget {
  const _RefreshableBody({required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _HomeFeedGrid extends StatelessWidget {
  const _HomeFeedGrid({
    required this.feed,
    required this.scrollController,
    required this.onRefresh,
    required this.revealIndex,
    required this.revealKey,
    required this.firstCardKey,
    required this.onVideoTap,
  });

  final FeedLoaded feed;
  final ScrollController scrollController;
  final RefreshCallback onRefresh;
  final int? revealIndex;
  final GlobalKey revealKey;
  final GlobalKey firstCardKey;
  final ValueChanged<int> onVideoTap;

  @override
  Widget build(BuildContext context) {
    final sections = _chunkFeedSections(feed.videos);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (
            var sectionIndex = 0;
            sectionIndex < sections.length;
            sectionIndex++
          ) ...[
            _HomeFeedSectionSliver(
              section: sections[sectionIndex],
              revealIndex: revealIndex,
              revealKey: revealKey,
              firstCardKey: firstCardKey,
              onVideoTap: onVideoTap,
            ),
            if (sections[sectionIndex].showsAdAfter)
              SliverToBoxAdapter(
                child: HomeFeedNativeAdCard(slotIndex: sectionIndex),
              ),
          ],
          if (feed.isLoadingMore && feed.videos.isNotEmpty)
            const FeedGridSkeletonSliver(
              itemCount: 2,
              padding: kFeedGridLoadMorePadding,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _HomeFeedSectionSliver extends StatelessWidget {
  const _HomeFeedSectionSliver({
    required this.section,
    required this.revealIndex,
    required this.revealKey,
    required this.firstCardKey,
    required this.onVideoTap,
  });

  final _HomeFeedSection section;
  final int? revealIndex;
  final GlobalKey revealKey;
  final GlobalKey firstCardKey;
  final ValueChanged<int> onVideoTap;

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
          final card = VideoFeedCard(
            key: globalIndex == revealIndex ? revealKey : null,
            videoId: video.id,
            thumbnailUrl: video.thumbnailUrl ?? '',
            title: video.title,
            username: video.username ?? '',
            sportId: video.sportId,
            viewCount: video.viewCount,
            rating: video.averageRating,
            onTap: () => onVideoTap(globalIndex),
          );

          if (globalIndex == 0) {
            return AppOnboardingTarget(
              targetKey: firstCardKey,
              title: AppStrings.homeOnboardingFirstVideoTitle,
              description: AppStrings.homeOnboardingFirstVideoTargetDescription,
              child: card,
            );
          }

          return card;
        }, childCount: section.videos.length),
      ),
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

/// Splits [videos] into grid sections, each followed by an ad slot except the
/// last: the first after [_firstAdInsertionIndex] videos, then every
/// [_subsequentAdInsertionInterval].
List<_HomeFeedSection> _chunkFeedSections(List<SportVideo> videos) {
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
