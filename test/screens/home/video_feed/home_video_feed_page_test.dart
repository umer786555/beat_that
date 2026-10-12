import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/screens/home/video_feed/presentation/widgets/home_video_feed_page.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const video = SportVideo(
    id: 'v0',
    userId: 'user-0',
    title: 'Video v0',
    description: '',
    videoPath: 'v0.mp4',
    thumbnailPath: 'v0.jpg',
  );
  const readySlot = VideoSlot(status: VideoSlotStatus.ready);

  late ValueNotifier<VideoSlot> slot;
  late int toggles;
  late int retries;

  setUp(() {
    slot = ValueNotifier(const VideoSlot.loading());
    toggles = 0;
    retries = 0;
  });

  tearDown(() => slot.dispose());

  Future<void> pumpPage(
    WidgetTester tester, {
    bool isCurrentVideo = true,
    bool showChrome = true,
    String? errorMessage,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeVideoFeedPage(
            video: video,
            slot: slot,
            isCurrentVideo: isCurrentVideo,
            errorMessage: errorMessage,
            isLoadingMore: false,
            showChrome: showChrome,
            onToggleChrome: () {},
            onTogglePlayback: () => toggles++,
            currentUserRating: null,
            onRetry: () => retries++,
          ),
        ),
      ),
    );
  }

  testWidgets('a loading current page shows a spinner and no controls', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a ready page shows the play toggle, which toggles playback', (
    tester,
  ) async {
    slot.value = readySlot;
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(toggles, 1);
  });

  testWidgets('a playing page shows the pause icon', (tester) async {
    slot.value = const VideoSlot(
      status: VideoSlotStatus.ready,
      isPlaying: true,
    );
    await pumpPage(tester);

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('the toggle is hidden off the current page', (tester) async {
    slot.value = readySlot;
    await pumpPage(tester, isCurrentVideo: false);

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('a slot error shows the retry overlay, which retries', (
    tester,
  ) async {
    slot.value = const VideoSlot(status: VideoSlotStatus.error);
    await pumpPage(tester);

    expect(find.text('Failed to load video. Tap to retry.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('a feed error shows its message while the video loads', (
    tester,
  ) async {
    await pumpPage(tester, errorMessage: 'This video is unavailable.');

    expect(find.text('This video is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the page rebuilds when its slot becomes ready', (tester) async {
    await pumpPage(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    slot.value = readySlot;
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
