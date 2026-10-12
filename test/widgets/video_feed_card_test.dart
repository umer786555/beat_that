import 'dart:async';
import 'dart:io';

import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thumbnail requests never complete, so the image stays pending.
class _PendingHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
}

/// Thumbnail requests fail immediately.
class _FailingHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Future.error(const SocketException('offline'));
}

void main() {
  final theme = ThemeData(colorSchemeSeed: Colors.pink);

  Widget buildCard(String thumbnailUrl) {
    return MaterialApp(
      theme: theme,
      home: Center(
        child: SizedBox(
          width: 180,
          height: 280,
          child: VideoFeedCard(
            videoId: 'video-1',
            thumbnailUrl: thumbnailUrl,
            viewCount: 1200,
            rating: 4.5,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  group('VideoFeedCard', () {
    testWidgets('shows a shimmer while the thumbnail is pending', (
      tester,
    ) async {
      debugNetworkImageHttpClientProvider = _PendingHttpClient.new;
      try {
        await tester.pumpWidget(buildCard('https://example.com/pending.jpg'));
        await tester.pump();
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }

      expect(find.byType(BeatShimmerFill), findsOneWidget);
      expect(find.byIcon(Icons.video_library_outlined), findsNothing);
    });

    testWidgets('shows a themed error tile when the thumbnail fails', (
      tester,
    ) async {
      debugNetworkImageHttpClientProvider = _FailingHttpClient.new;
      try {
        await tester.pumpWidget(buildCard('https://example.com/broken.jpg'));
        await tester.pump();
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.video_library_outlined),
      );
      final tile = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.byIcon(Icons.video_library_outlined),
              matching: find.byType(ColoredBox),
            )
            .first,
      );

      expect(tile.color, theme.colorScheme.surfaceContainerHighest);
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
      expect(find.byType(BeatShimmerFill), findsNothing);
    });
  });
}
