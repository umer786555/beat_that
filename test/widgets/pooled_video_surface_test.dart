import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:beat_that/widgets/pooled_video_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  const thumbnailUrl = 'https://example.com/thumb.jpg';
  const errorSlot = VideoSlot(status: VideoSlotStatus.error);
  const readySlot = VideoSlot(status: VideoSlotStatus.ready);

  Future<void> pumpSurface(
    WidgetTester tester, {
    required VideoSlot slot,
    String? thumbnailUrl = thumbnailUrl,
    bool showLoadingIndicator = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: PooledVideoSurface(
          slot: slot,
          thumbnailUrl: thumbnailUrl,
          showLoadingIndicator: showLoadingIndicator,
        ),
      ),
    );
  }

  group('PooledVideoSurface', () {
    testWidgets('loading shows the thumbnail and a spinner', (tester) async {
      await pumpSurface(tester, slot: const VideoSlot.loading());

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading hides the spinner off the current page', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        slot: const VideoSlot.loading(),
        showLoadingIndicator: false,
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error shows the thumbnail without a spinner', (tester) async {
      await pumpSurface(tester, slot: errorSlot);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a missing thumbnail falls back to the black placeholder', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        slot: const VideoSlot.loading(),
        thumbnailUrl: null,
      );

      expect(find.byType(Image), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PooledVideoSurface),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == Colors.black,
          ),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('a thumbnail that fails to load shows the placeholder', (
      tester,
    ) async {
      await pumpSurface(tester, slot: errorSlot);
      // Widget tests answer every network image with HTTP 400.
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Image),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == Colors.black,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ready hides the thumbnail and spinner', (tester) async {
      // A real VideoController needs the native player, so the `Video` layer
      // itself is covered by the manual device checks.
      await pumpSurface(tester, slot: readySlot);

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Video), findsNothing);
    });
  });

  group('videoErrorOverlayMessage', () {
    test('is null off the current page', () {
      expect(
        videoErrorOverlayMessage(
          slot: errorSlot,
          errorMessage: 'Failed to load more videos.',
          isCurrentVideo: false,
        ),
        isNull,
      );
    });

    test('is null once the video is ready', () {
      expect(
        videoErrorOverlayMessage(
          slot: readySlot,
          errorMessage: 'Failed to load more videos.',
          isCurrentVideo: true,
        ),
        isNull,
      );
    });

    test('reports a slot error', () {
      expect(
        videoErrorOverlayMessage(
          slot: errorSlot,
          errorMessage: null,
          isCurrentVideo: true,
        ),
        'Failed to load video. Tap to retry.',
      );
    });

    test('shows the cubit error while the video is loading', () {
      expect(
        videoErrorOverlayMessage(
          slot: const VideoSlot.loading(),
          errorMessage: 'This video is unavailable.',
          isCurrentVideo: true,
        ),
        'This video is unavailable.',
      );
    });

    test('is null while loading without an error', () {
      expect(
        videoErrorOverlayMessage(
          slot: const VideoSlot.loading(),
          errorMessage: null,
          isCurrentVideo: true,
        ),
        isNull,
      );
    });
  });
}
