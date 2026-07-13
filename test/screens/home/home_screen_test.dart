import 'dart:async';

import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/screens/home/home_screen.dart';
import 'package:beat_that/widgets/shimmer_loading.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
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
      'thumbnail_url': 'https://example.com/thumb1.jpg',
      'username': 'user1',
      'view_count': 100,
      'average_rating': 4.5,
      'source': 'personalized',
    },
    {
      'id': 'video-2',
      'thumbnail_url': 'https://example.com/thumb2.jpg',
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
}
