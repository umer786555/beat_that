import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/screens/play_uploaded_video.dart/bloc/play_uploaded_video_bloc.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:beat_that/services/video_playback/video_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_playback_player.dart';

class MockVideoSourceResolver extends Mock implements VideoSourceResolver {}

void main() {
  const videoPath = 'videos/clip.mp4';
  const source = 'https://cdn/videos/clip.mp4';
  const loaded = PlaybackProgress(
    position: Duration.zero,
    duration: Duration(seconds: 20),
    isPlaying: false,
  );

  late MockVideoSourceResolver resolver;
  late List<FakePlaybackPlayer> created;

  /// Delivers pending async work, such as the resolver and `open()`.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  /// Adds [InitializeVideoEvent] and completes loading on the new player.
  Future<FakePlaybackPlayer> initialize(PlayUploadedVideoBloc bloc) async {
    bloc.add(const InitializeVideoEvent());
    await flush();
    final player = created.last;
    player.emitProgress(loaded);
    await flush();
    return player;
  }

  setUp(() {
    resolver = MockVideoSourceResolver();
    created = [];
    when(() => resolver.resolve(videoPath)).thenAnswer((_) async => source);

    GetIt.instance
      ..registerSingleton<VideoSourceResolver>(resolver)
      ..registerFactory<PlaybackPlayer>(() {
        final player = FakePlaybackPlayer();
        created.add(player);
        return player;
      });
  });

  tearDown(() => GetIt.instance.reset());

  group('initialize', () {
    test('opens the resolved source paused and emits ready', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final states = <PlayUploadedVideoState>[];
      final subscription = bloc.stream.listen(states.add);

      final player = await initialize(bloc);

      expect(player.openCalls, [(source: source, play: false, loop: false)]);
      expect(states, [
        PlayUploadedVideoLoading(),
        const PlayUploadedVideoReady(
          duration: Duration(seconds: 20),
          currentPosition: Duration.zero,
          isPlaying: false,
        ),
      ]);
      expect(bloc.player, same(player));
      await subscription.cancel();
      await bloc.close();
    });

    test('waits for a non-zero duration before emitting ready', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      bloc.add(const InitializeVideoEvent());
      await flush();

      created.single.emitProgress(PlaybackProgress.zero);
      await flush();

      expect(bloc.state, isA<PlayUploadedVideoLoading>());
      await bloc.close();
    });

    test('emits error when the player reports an error', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      bloc.add(const InitializeVideoEvent());
      await flush();

      created.single.emitError('codec not supported');
      await flush();

      expect(bloc.state, isA<PlayUploadedVideoError>());
      await bloc.close();
    });

    test('emits error when the source cannot be resolved', () async {
      when(
        () => resolver.resolve(videoPath),
      ).thenAnswer((_) async => throw Exception('not found'));
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);

      bloc.add(const InitializeVideoEvent());
      await flush();

      expect(bloc.state, isA<PlayUploadedVideoError>());
      expect(created.single.openCalls, isEmpty);
      await bloc.close();
    });

    test(
      'emits error when open() throws, with no unhandled error after close',
      () async {
        GetIt.instance
          ..unregister<PlaybackPlayer>()
          ..registerFactory<PlaybackPlayer>(() {
            final player = FakePlaybackPlayer(holdOpens: true);
            created.add(player);
            return player;
          });
        final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
        bloc.add(const InitializeVideoEvent());
        await flush();

        created.single.failOpens(Exception('player disposed'));
        await flush();
        expect(bloc.state, isA<PlayUploadedVideoError>());

        // Disposing closes the progress stream the load was waiting on.
        await bloc.close();
        await flush();
        expect(created.single.isDisposed, isTrue);
      },
    );

    test('retrying disposes the previous player', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final first = await initialize(bloc);

      final second = await initialize(bloc);

      expect(first.isDisposed, isTrue);
      expect(second.isDisposed, isFalse);
      expect(bloc.player, same(second));
      await bloc.close();
    });
  });

  group('playback', () {
    test('play and pause map onto the player', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final player = await initialize(bloc);

      bloc.add(const PlayVideoEvent());
      await flush();
      expect(player.isPlaying, isTrue);
      expect(bloc.state, isA<PlayUploadedVideoPlaying>());

      player.emitProgress(
        loaded.copyWith(position: const Duration(seconds: 4), isPlaying: true),
      );
      bloc.add(const PauseVideoEvent());
      await flush();
      expect(player.isPlaying, isFalse);
      expect(
        bloc.state,
        const PlayUploadedVideoPaused(
          duration: Duration(seconds: 20),
          currentPosition: Duration(seconds: 4),
        ),
      );
      await bloc.close();
    });

    test('seek maps onto the player and keeps the play state', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final player = await initialize(bloc);
      bloc.add(const PlayVideoEvent());
      await flush();

      bloc.add(const SeekVideoEvent(Duration(seconds: 7)));
      await flush();

      expect(player.seeks, [const Duration(seconds: 7)]);
      expect(
        bloc.state,
        const PlayUploadedVideoPlaying(
          duration: Duration(seconds: 20),
          currentPosition: Duration(seconds: 7),
        ),
      );
      await bloc.close();
    });

    test('progress exposes the latest player progress', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final player = await initialize(bloc);
      final later = loaded.copyWith(position: const Duration(seconds: 9));

      player.emitProgress(later);
      await flush();

      expect(bloc.progress, later);
      await bloc.close();
    });
  });

  group('dispose', () {
    test('close disposes the player', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final player = await initialize(bloc);

      await bloc.close();

      expect(player.isDisposed, isTrue);
    });

    test('close disposes a player that is still loading', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      bloc.add(const InitializeVideoEvent());
      await flush();

      await bloc.close();

      expect(created.single.isDisposed, isTrue);
    });

    test('DisposeVideoEvent disposes the player and is idempotent', () async {
      final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
      final player = await initialize(bloc);

      bloc
        ..add(const DisposeVideoEvent())
        ..add(const DisposeVideoEvent());
      await flush();

      expect(player.isDisposed, isTrue);
      expect(bloc.player, isNull);
      await bloc.close();
    });

    test('20 open/close cycles leave every player disposed', () async {
      for (var i = 0; i < 20; i++) {
        final bloc = PlayUploadedVideoBloc(videoPath: videoPath);
        if (i.isEven) {
          await initialize(bloc);
        } else {
          bloc.add(const InitializeVideoEvent());
        }
        await bloc.close();
      }

      expect(created, hasLength(20));
      expect(created.map((player) => player.isDisposed), everyElement(isTrue));
    });
  });
}
