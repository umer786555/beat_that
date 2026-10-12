import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_playback_player.dart';

void main() {
  late List<FakePlaybackPlayer> created;
  late bool holdOpens;
  late Object owner;
  late VideoPlayerPool pool;

  VideoPlayerPool buildPool({
    int size = 5,
    Future<String> Function(String key)? resolveSource,
  }) {
    return VideoPlayerPool(
      createPlayer: () {
        final player = FakePlaybackPlayer(holdOpens: holdOpens);
        created.add(player);
        return player;
      },
      resolveSource: resolveSource ?? (key) async => 'https://cdn/$key',
      size: size,
    );
  }

  /// Lets every pending resolve and open() complete.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  List<String> keys(int count) => [for (var i = 0; i < count; i++) 'v$i'];

  /// The player whose latest open() loaded [key].
  FakePlaybackPlayer playerFor(String key) => created.singleWhere(
    (player) =>
        player.openedSources.isNotEmpty &&
        player.openedSources.last == 'https://cdn/$key',
  );

  Iterable<FakePlaybackPlayer> playing() =>
      created.where((player) => player.isPlaying);

  setUp(() {
    created = [];
    holdOpens = false;
    owner = Object();
    pool = buildPool()..claim(owner);
  });

  group('reuse by key', () {
    test('requesting the same videoPath twice opens it once', () async {
      pool.setWindow(keys: ['a', 'a', 'b'], activeIndex: 0);
      await flush();
      pool.setWindow(keys: ['a', 'a', 'b'], activeIndex: 0);
      await flush();

      expect(created, hasLength(2));
      expect(playerFor('a').openedSources, ['https://cdn/a']);
    });

    test(
      'moving the window keeps already loaded keys on their players',
      () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        final v1Player = playerFor('v1');

        pool.setWindow(keys: keys(10), activeIndex: 1);
        await flush();

        expect(playerFor('v1'), same(v1Player));
        expect(v1Player.openedSources, ['https://cdn/v1']);
      },
    );

    test('pages with the same key share one slot', () {
      expect(pool.slotFor('a'), same(pool.slotFor('a')));
    });
  });

  group('preload window', () {
    test('opens active, 2 ahead and 1 behind, paused and looping', () async {
      pool.setWindow(keys: keys(10), activeIndex: 3);
      await flush();

      expect(created, hasLength(4));
      expect(
        created.map((player) => player.openedSources.single),
        unorderedEquals([
          'https://cdn/v2',
          'https://cdn/v3',
          'https://cdn/v4',
          'https://cdn/v5',
        ]),
      );
      for (final player in created) {
        expect(player.openCalls.single.play, isFalse);
        expect(player.openCalls.single.loop, isTrue);
      }
    });

    test('only the active video plays', () async {
      pool.setWindow(keys: keys(10), activeIndex: 3);
      await flush();

      expect(playing(), [playerFor('v3')]);
    });

    test('skips out-of-range indexes', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      expect(
        created.map((player) => player.openedSources.single),
        unorderedEquals(['https://cdn/v0', 'https://cdn/v1', 'https://cdn/v2']),
      );

      created.clear();
      pool = buildPool()..claim(owner);
      pool.setWindow(keys: keys(3), activeIndex: 2);
      await flush();
      expect(
        created.map((player) => player.openedSources.single),
        unorderedEquals(['https://cdn/v1', 'https://cdn/v2']),
      );
    });

    test('skips empty keys', () async {
      pool.setWindow(keys: ['v0', '', 'v2'], activeIndex: 0);
      await flush();

      expect(
        created.map((player) => player.openedSources.single),
        unorderedEquals(['https://cdn/v0', 'https://cdn/v2']),
      );
    });

    test('an empty active key plays nothing', () async {
      pool.setWindow(keys: ['', 'v1', 'v2'], activeIndex: 0);
      await flush();

      expect(playing(), isEmpty);
    });

    test('never exceeds the pool size', () async {
      pool = buildPool(size: 2)..claim(owner);
      pool.setWindow(keys: keys(10), activeIndex: 3);
      await flush();

      expect(created, hasLength(2));
      expect(
        created.map((player) => player.openedSources.single),
        unorderedEquals(['https://cdn/v3', 'https://cdn/v4']),
      );
    });
  });

  group('LRU eviction', () {
    test('reuses the least recently used player outside the window', () async {
      for (var index = 0; index <= 2; index++) {
        pool.setWindow(keys: keys(10), activeIndex: index);
        await flush();
      }
      expect(created, hasLength(5));
      final v0Player = playerFor('v0');
      final v1Player = playerFor('v1');

      pool.setWindow(keys: keys(10), activeIndex: 3);
      await flush();

      expect(created, hasLength(5));
      expect(playerFor('v5'), same(v0Player));
      expect(playerFor('v1'), same(v1Player));
      expect(created.any((player) => player.isDisposed), isFalse);
    });

    test(
      'resets the evicted slot to loading before reopening the player',
      () async {
        for (var index = 0; index <= 2; index++) {
          pool.setWindow(keys: keys(10), activeIndex: index);
          await flush();
        }
        final v0Player = playerFor('v0')..emitWidth(1080);
        await flush();
        final v0Slot = pool.slotFor('v0');
        expect(v0Slot.value.status, VideoSlotStatus.ready);

        final opensWhenReset = <int>[];
        v0Slot.addListener(
          () => opensWhenReset.add(v0Player.openedSources.length),
        );

        pool.setWindow(keys: keys(10), activeIndex: 3);
        expect(v0Slot.value, const VideoSlot.loading());
        expect(v0Slot.value.videoController, isNull);
        await flush();

        expect(opensWhenReset, [1]);
        expect(v0Player.openedSources.last, 'https://cdn/v5');
      },
    );

    test('pauses an evicted player that was playing', () async {
      pool = buildPool(size: 1)..claim(owner);
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      final player = created.single;
      expect(player.isPlaying, isTrue);

      player.holdOpens = true;
      pool.setWindow(keys: keys(10), activeIndex: 5);

      expect(player.isPlaying, isFalse);
    });
  });

  group('activation', () {
    test('swiping back restarts the video at 0', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      playerFor('v0').emitProgress(
        const PlaybackProgress(
          position: Duration(seconds: 4),
          duration: Duration(seconds: 10),
          isPlaying: true,
        ),
      );
      await flush();

      pool.setWindow(keys: keys(10), activeIndex: 1);
      pool.setWindow(keys: keys(10), activeIndex: 0);

      expect(playerFor('v0').seeks, [Duration.zero]);
    });

    test('activating another video clears the user pause', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      pool.toggleActivePlayback();
      expect(playing(), isEmpty);

      pool.setWindow(keys: keys(10), activeIndex: 1);

      expect(playing(), [playerFor('v1')]);
    });
  });

  group('active progress', () {
    test('forwards progress from the active player only', () async {
      final forwarded = <PlaybackProgress>[];
      pool.activeProgress.listen(forwarded.add);
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      const progress = PlaybackProgress(
        position: Duration(seconds: 1),
        duration: Duration(seconds: 10),
        isPlaying: true,
      );

      playerFor('v1').emitProgress(progress);
      playerFor('v0').emitProgress(progress);
      await flush();

      expect(forwarded, [progress]);
    });

    test('mirrors play state into the slot', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      playerFor(
        'v0',
      ).emitProgress(PlaybackProgress.zero.copyWith(isPlaying: true));
      await flush();

      expect(pool.slotFor('v0').value.isPlaying, isTrue);
    });
  });

  group('pause reasons', () {
    for (final reason in PauseReason.values) {
      test(
        '$reason pauses every player and removing it resumes the active one',
        () async {
          pool.setWindow(keys: keys(10), activeIndex: 0);
          await flush();

          pool.addPauseReason(reason);
          expect(playing(), isEmpty);

          pool.removePauseReason(reason);
          expect(playing(), [playerFor('v0')]);
        },
      );

      test('$reason does not resume a video the user paused', () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        pool.toggleActivePlayback();

        pool.addPauseReason(reason);
        pool.removePauseReason(reason);
        expect(playing(), isEmpty);

        pool.toggleActivePlayback();
        expect(playing(), [playerFor('v0')]);
      });
    }

    test('playback waits until every reason is removed', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      pool
        ..addPauseReason(PauseReason.ad)
        ..addPauseReason(PauseReason.covered)
        ..removePauseReason(PauseReason.ad);
      expect(playing(), isEmpty);

      pool.removePauseReason(PauseReason.covered);
      expect(playing(), [playerFor('v0')]);
    });

    test(
      'an open() finishing in the background does not start playback',
      () async {
        holdOpens = true;
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        pool.addPauseReason(PauseReason.background);

        for (final player in created) {
          player.completeOpens();
        }
        await flush();
        expect(playing(), isEmpty);

        pool.removePauseReason(PauseReason.background);
        expect(playing(), [playerFor('v0')]);
      },
    );

    test('release clears covered and ad but keeps background', () async {
      pool
        ..addPauseReason(PauseReason.covered)
        ..addPauseReason(PauseReason.ad)
        ..release(owner)
        ..claim(owner)
        ..setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      expect(playing(), [playerFor('v0')]);

      pool
        ..addPauseReason(PauseReason.background)
        ..release(owner)
        ..claim(owner)
        ..setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      expect(playing(), isEmpty);
    });
  });

  group('plays before ready', () {
    test(
      'the active video plays once open() completes, without width',
      () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();

        expect(playerFor('v0').isPlaying, isTrue);
        expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);
      },
    );

    test('width > 0 after open() marks the slot ready', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      playerFor('v0').emitWidth(1080);
      await flush();

      expect(pool.slotFor('v0').value.status, VideoSlotStatus.ready);
    });

    test(
      'a width reported before open() completes is ignored until then',
      () async {
        holdOpens = true;
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        final player = created.first..emitWidth(1080);
        await flush();
        expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);

        player.completeOpens();
        await flush();

        expect(pool.slotFor('v0').value.status, VideoSlotStatus.ready);
      },
    );

    test('a null width from open() discards an earlier stale width', () async {
      holdOpens = true;
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      final player = created.first
        ..emitWidth(1080)
        ..emitWidth(null);
      await flush();

      player.completeOpens();
      await flush();

      expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);
    });
  });

  group('stale open', () {
    test('an open() finishing after its key was evicted is dropped', () async {
      pool = buildPool(size: 1)..claim(owner);
      holdOpens = true;
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();
      final statuses = <VideoSlotStatus>[];
      final v0Slot = pool.slotFor('v0');
      v0Slot.addListener(() => statuses.add(v0Slot.value.status));

      pool.setWindow(keys: keys(10), activeIndex: 5);
      await flush();
      final player = created.single
        ..completeOpens()
        ..emitWidth(1080);
      await flush();

      expect(statuses, isNot(contains(VideoSlotStatus.ready)));
      expect(v0Slot.value.status, VideoSlotStatus.loading);
      expect(pool.slotFor('v5').value.status, VideoSlotStatus.ready);
      expect(player.isPlaying, isTrue);
    });

    test(
      'an open() finishing after release() never plays or marks ready',
      () async {
        holdOpens = true;
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();

        pool.release(owner);
        for (final player in created) {
          player
            ..completeOpens()
            ..emitWidth(1080);
        }
        await flush();

        expect(playing(), isEmpty);
        expect(created.where((player) => player.isLoaded), isEmpty);
        expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);
      },
    );

    test('a resolve finishing after release() never opens', () async {
      final pending = <String, Future<String>>{};
      pool = buildPool(
        resolveSource: (key) => pending[key] = Future<String>.delayed(
          const Duration(milliseconds: 10),
          () => 'https://cdn/$key',
        ),
      )..claim(owner);
      pool.setWindow(keys: keys(10), activeIndex: 0);

      pool.release(owner);
      await Future.wait(pending.values);
      await flush();

      expect(created.expand((player) => player.openCalls), isEmpty);
    });
  });

  group('error and retry', () {
    test('an open() exception marks the slot error', () async {
      holdOpens = true;
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      created.first.failOpens(Exception('decoder failed'));
      await flush();

      expect(pool.slotFor('v0').value.status, VideoSlotStatus.error);
    });

    test('a resolve exception marks the slot error', () async {
      pool = buildPool(
        resolveSource: (key) async =>
            key == 'v1' ? throw Exception('no url') : 'https://cdn/$key',
      )..claim(owner);
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      expect(pool.slotFor('v1').value.status, VideoSlotStatus.error);
      expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);
    });

    test('an error event marks the slot error', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      playerFor('v0').emitError('network down');
      await flush();

      expect(pool.slotFor('v0').value.status, VideoSlotStatus.error);
    });

    test(
      'retry reopens the key and can reach ready without touching others',
      () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        playerFor('v1').emitWidth(720);
        playerFor('v0').emitError('network down');
        await flush();
        final v1Player = playerFor('v1');

        pool.retry('v0');
        expect(pool.slotFor('v0').value.status, VideoSlotStatus.loading);
        await flush();
        playerFor('v0').emitWidth(1080);
        await flush();

        expect(playerFor('v0').openedSources, [
          'https://cdn/v0',
          'https://cdn/v0',
        ]);
        expect(pool.slotFor('v0').value.status, VideoSlotStatus.ready);
        expect(pool.slotFor('v1').value.status, VideoSlotStatus.ready);
        expect(v1Player.openedSources, hasLength(1));
      },
    );

    test('retry of an unbound key does nothing', () {
      pool.retry('unknown');

      expect(created, isEmpty);
    });
  });

  group('ownership', () {
    test('release() from a non-owner is a no-op', () async {
      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      pool.release(Object());

      expect(created.every((player) => player.stopCount == 0), isTrue);
      expect(playing(), [playerFor('v0')]);
    });

    test(
      'release() from the owner stops every player without disposing',
      () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();

        pool.release(owner);

        for (final player in created) {
          expect(player.stopCount, 1);
          expect(player.isLoaded, isFalse);
          expect(player.isDisposed, isFalse);
        }
        expect(pool.slotFor('v0').value, const VideoSlot.loading());
      },
    );

    test('setWindow() without an owner does nothing', () async {
      pool.release(owner);

      pool.setWindow(keys: keys(10), activeIndex: 0);
      await flush();

      expect(created, isEmpty);
    });

    test(
      'a new claim releases the previous owner, whose late release is ignored',
      () async {
        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();

        final nextOwner = Object();
        pool.claim(nextOwner);
        expect(created.every((player) => player.stopCount == 1), isTrue);

        pool.setWindow(keys: keys(10), activeIndex: 0);
        await flush();
        pool.release(owner);

        expect(playing(), [playerFor('v0')]);
        expect(created.every((player) => player.stopCount == 1), isTrue);
      },
    );
  });
}
