import 'dart:math';

import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_playback_player.dart';

void main() {
  test('200 swipes stay within 5 players with at most one playing', () async {
    final created = <FakePlaybackPlayer>[];
    final pool = VideoPlayerPool(
      createPlayer: () {
        final player = FakePlaybackPlayer();
        created.add(player);
        return player;
      },
      resolveSource: (key) async => 'https://cdn/$key',
    );
    final owner = Object();
    final keys = [for (var i = 0; i < 120; i++) 'v$i'];
    final random = Random(42);
    var index = 0;

    pool.claim(owner);
    for (var swipe = 0; swipe < 200; swipe++) {
      final roll = random.nextDouble();
      final step = roll < 0.6
          ? 1
          : roll < 0.8
          ? -1
          // A fling jumps several pages in either direction.
          : (random.nextBool() ? 1 : -1) * (3 + random.nextInt(6));
      index = (index + step).clamp(0, keys.length - 1);

      pool.setWindow(owner: owner, keys: keys, activeIndex: index);
      // Flings don't wait for opens to finish; normal swipes do.
      if (step.abs() == 1) {
        await Future<void>.delayed(Duration.zero);
        for (final player in created.where((player) => player.isLoaded)) {
          player.emitWidth(1080);
        }
      }

      expect(created.length, lessThanOrEqualTo(5), reason: 'swipe $swipe');
      expect(
        created.where((player) => player.isPlaying).length,
        lessThanOrEqualTo(1),
        reason: 'swipe $swipe',
      );
      expect(created.where((player) => player.isDisposed), isEmpty);
    }

    pool.release(owner);
    await Future<void>.delayed(Duration.zero);

    expect(created.where((player) => player.isLoaded), isEmpty);
    expect(created.where((player) => player.isPlaying), isEmpty);
    expect(created.where((player) => player.isDisposed), isEmpty);
  });
}
