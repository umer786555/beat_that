import 'dart:async';

import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/screens/home/home_screen.dart';
import 'package:beat_that/widgets/shimmer_loading.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

void main() {
  late MockHomeBloc homeBloc;

  const loadedVideos = [
    {
      'id': 'video-1',
      'thumbnailUrl': 'https://example.com/thumb1.jpg',
      'thumbnail_path': 'profiles/user-1/thumbnails/thumb1.jpg',
      'video_path': 'profiles/user-1/videos/video1.mp4',
      'title': 'Top spin rally',
      'username': 'user1',
      'view_count': 100,
      'average_rating': 4.5,
      'source': 'personalized',
    },
    {
      'id': 'video-2',
      'thumbnailUrl': 'https://example.com/thumb2.jpg',
      'thumbnail_path': 'profiles/user-2/thumbnails/thumb2.jpg',
      'video_path': 'profiles/user-2/videos/video2.mp4',
      'title': 'Winning serve',
      'username': 'user2',
      'view_count': 50,
      'average_rating': 4.0,
      'source': 'trending',
    },
  ];

  Widget buildTestApp(HomeBloc bloc) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<HomeBloc>.value(
            value: bloc,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/username-setup',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  setUp(() {
    homeBloc = MockHomeBloc();
  });

  testWidgets('keeps loaded videos visible while pagination is loading', (
    tester,
  ) async {
    const loadedState = FeedLoaded(
      videos: loadedVideos,
      offset: 0,
      hasMoreContent: true,
    );
    const paginationLoadingState = FeedLoading(offset: 2, isFirstLoad: false);

    when(() => homeBloc.state).thenReturn(loadedState);
    whenListen(
      homeBloc,
      Stream<HomeState>.fromIterable([loadedState, paginationLoadingState]),
      initialState: loadedState,
    );

    await tester.pumpWidget(buildTestApp(homeBloc));
    await tester.pump();

    expect(find.byType(VideoFeedCard), findsNWidgets(2));
    expect(find.text('Top spin rally'), findsOneWidget);
    expect(find.text('@user1'), findsOneWidget);
    expect(find.byType(ShimmerLoading), findsNothing);

    await tester.pump();

    expect(find.byType(VideoFeedCard), findsNWidgets(2));
    expect(find.text('@user1'), findsOneWidget);
    expect(find.byType(ShimmerLoadingIndicator), findsOneWidget);
  });

  testWidgets(
    'shows loading UI while user profile is loaded before feed fetch completes',
    (tester) async {
      final profileLoadedState = UserProfileLoaded(
        UserPersonalProfile(username: 'user1'),
      );

      when(() => homeBloc.state).thenReturn(profileLoadedState);
      whenListen(
        homeBloc,
        Stream<HomeState>.value(profileLoadedState),
        initialState: profileLoadedState,
      );

      await tester.pumpWidget(buildTestApp(homeBloc));
      await tester.pump();

      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(VideoFeedCard), findsNothing);
    },
  );

  testWidgets('refresh waits for the next terminal bloc state', (tester) async {
    final controller = StreamController<HomeState>();
    addTearDown(controller.close);
    final platformCalls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    const loadedState = FeedLoaded(
      videos: loadedVideos,
      offset: 0,
      hasMoreContent: true,
    );

    when(() => homeBloc.state).thenReturn(loadedState);
    whenListen(homeBloc, controller.stream, initialState: loadedState);

    await tester.pumpWidget(buildTestApp(homeBloc));
    await tester.pump();

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    var refreshCompleted = false;
    final refreshFuture = refreshIndicator.onRefresh().then((_) {
      refreshCompleted = true;
    });

    await tester.pump();

    verify(() => homeBloc.add(const RefreshFeedEvent())).called(1);
    expect(
      platformCalls.any(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );
    expect(refreshCompleted, isFalse);

    controller.add(const FeedLoading(offset: 0, isFirstLoad: true));
    await tester.pump();
    expect(refreshCompleted, isFalse);

    controller.add(
      const FeedLoaded(videos: loadedVideos, offset: 0, hasMoreContent: true),
    );

    await refreshFuture;
    expect(refreshCompleted, isTrue);
  });

  testWidgets('shows pull-to-refresh on empty feed state', (tester) async {
    const emptyState = FeedLoaded(videos: [], offset: 0, hasMoreContent: false);

    when(() => homeBloc.state).thenReturn(emptyState);
    whenListen(
      homeBloc,
      Stream<HomeState>.value(emptyState),
      initialState: emptyState,
    );

    await tester.pumpWidget(buildTestApp(homeBloc));
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('No videos yet'), findsOneWidget);
  });

  testWidgets('shows pull-to-refresh on error state', (tester) async {
    const errorState = FeedError(message: 'network failed');

    when(() => homeBloc.state).thenReturn(errorState);
    whenListen(
      homeBloc,
      Stream<HomeState>.value(errorState),
      initialState: errorState,
    );

    await tester.pumpWidget(buildTestApp(homeBloc));
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Failed to load videos'), findsOneWidget);
  });
}
