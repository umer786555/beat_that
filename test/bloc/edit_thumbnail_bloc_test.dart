import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:beat_that/models/category.dart';
import 'package:beat_that/models/subcategory.dart';
import 'package:beat_that/screens/edit_thumbnail/bloc/edit_thumbnail_bloc.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

class MockVideoPickerService extends Mock implements VideoPickerService {}

class MockPreferencesService extends Mock implements PreferencesService {}

class FakeFile extends Fake implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseService mockSupabaseService;
  late MockVideoPickerService mockVideoPickerService;
  late MockPreferencesService mockPreferencesService;

  setUpAll(() {
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    mockVideoPickerService = MockVideoPickerService();
    mockPreferencesService = MockPreferencesService();

    locator.registerSingleton<SupabaseService>(mockSupabaseService);
    locator.registerSingleton<VideoPickerService>(mockVideoPickerService);
    locator.registerSingleton<PreferencesService>(mockPreferencesService);
  });

  tearDown(() async {
    await locator.reset();
  });

  test('saves game uploads with category name as sportId', () async {
    final tempDir = await Directory.systemTemp.createTemp('edit-thumb-test');
    final videoFile = File('${tempDir.path}/video.mp4');
    await videoFile.writeAsBytes(const <int>[1, 2, 3]);

    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    when(
      () => mockSupabaseService.uploadVideoWithThumbnail(
        videoFile: any(named: 'videoFile'),
        thumbnailFile: any(named: 'thumbnailFile'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        sportId: any(named: 'sportId'),
        subcategoryId: any(named: 'subcategoryId'),
        subcategoryName: any(named: 'subcategoryName'),
        customOptionName: any(named: 'customOptionName'),
        onVideoProgress: any(named: 'onVideoProgress'),
      ),
    ).thenAnswer((_) async => {'success': true, 'message': 'ok'});

    final bloc = EditThumbnailBloc(
      videoPath: videoFile.path,
      videoDuration: const Duration(seconds: 12),
      sport: const CategoryModel(
        id: '42',
        name: 'valorant',
        displayName: 'Valorant',
        subcategories: <Subcategorys>[],
      ),
    );
    addTearDown(bloc.close);

    bloc.selectedThumbnail = Uint8List.fromList(const <int>[1, 2, 3]);
    final saveCompleted = bloc.stream.firstWhere(
      (state) => state is ThumbnailsGeneratedState,
    );
    bloc.add(const SaveEvent(title: 'Clip title'));

    await untilCalled(
      () => mockSupabaseService.uploadVideoWithThumbnail(
        videoFile: any(named: 'videoFile'),
        thumbnailFile: any(named: 'thumbnailFile'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        sportId: any(named: 'sportId'),
        subcategoryId: any(named: 'subcategoryId'),
        subcategoryName: any(named: 'subcategoryName'),
        customOptionName: any(named: 'customOptionName'),
        onVideoProgress: any(named: 'onVideoProgress'),
      ),
    );

    verify(
      () => mockSupabaseService.uploadVideoWithThumbnail(
        videoFile: any(named: 'videoFile'),
        thumbnailFile: any(named: 'thumbnailFile'),
        title: 'Clip title',
        description: '',
        sportId: 'valorant',
        subcategoryId: null,
        subcategoryName: null,
        customOptionName: null,
        onVideoProgress: any(named: 'onVideoProgress'),
      ),
    ).called(1);

    await saveCompleted;
  });

  test('rejects too-short video before generating thumbnails', () async {
    final bloc = EditThumbnailBloc(
      videoPath: '/does/not/matter.mp4',
      videoDuration: const Duration(milliseconds: 9999),
      sport: const CategoryModel(
        id: '42',
        name: 'valorant',
        displayName: 'Valorant',
        subcategories: <Subcategorys>[],
      ),
    );
    addTearDown(bloc.close);

    final presentation = bloc.presentation.first;
    bloc.add(const InitialEvent());

    expect(await presentation, isA<VideoTooShortEvent>());
    expect(bloc.state, isA<EditThumbnailInitial>());
  });

  group('frameTimestamps', () {
    test('returns one ordered timestamp per segment inside trimmed range', () {
      for (var seed = 0; seed < 50; seed++) {
        final timestamps = EditThumbnailBloc.frameTimestamps(
          60000,
          random: Random(seed),
        );

        expect(timestamps, hasLength(5));
        expect(timestamps.first, greaterThanOrEqualTo(3000));
        expect(timestamps.last, lessThanOrEqualTo(57000));
        for (var i = 1; i < timestamps.length; i++) {
          // Jitter stays in the middle half of each 10.8s segment.
          expect(timestamps[i] - timestamps[i - 1], greaterThan(5000));
        }
      }
    });

    test('does not throw for zero duration', () {
      expect(EditThumbnailBloc.frameTimestamps(0), everyElement(0));
    });
  });

  test(
    'uploads thumbnail with extension matching its bytes and cleans up',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('edit-thumb-test');
      final videoFile = File('${tempDir.path}/video.mp4');
      await videoFile.writeAsBytes(const <int>[1, 2, 3]);
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      File? uploadedThumbnail;
      String? uploadedExtension;
      when(
        () => mockSupabaseService.uploadVideoWithThumbnail(
          videoFile: any(named: 'videoFile'),
          thumbnailFile: any(named: 'thumbnailFile'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          sportId: any(named: 'sportId'),
          subcategoryId: any(named: 'subcategoryId'),
          subcategoryName: any(named: 'subcategoryName'),
          customOptionName: any(named: 'customOptionName'),
          onVideoProgress: any(named: 'onVideoProgress'),
        ),
      ).thenAnswer((invocation) async {
        uploadedThumbnail = invocation.namedArguments[#thumbnailFile] as File;
        uploadedExtension = uploadedThumbnail!.path.split('.').last;
        return {'success': true, 'message': 'ok'};
      });

      final bloc = EditThumbnailBloc(
        videoPath: videoFile.path,
        videoDuration: const Duration(seconds: 12),
        sport: const CategoryModel(
          id: '42',
          name: 'valorant',
          displayName: 'Valorant',
          subcategories: <Subcategorys>[],
        ),
      );
      addTearDown(bloc.close);

      // JPEG signature, as produced by frame extraction.
      bloc.selectedThumbnail = Uint8List.fromList(const <int>[
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0,
        0,
      ]);
      final saveCompleted = bloc.stream.firstWhere(
        (state) => state is ThumbnailsGeneratedState,
      );
      bloc.add(const SaveEvent(title: 'Clip title'));
      await saveCompleted;
      // Temp dir is deleted in the handler's finally, after the state emit.
      final thumbnailDir = uploadedThumbnail!.parent;
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (await thumbnailDir.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(uploadedExtension, 'jpg');
      expect(await thumbnailDir.exists(), isFalse);
    },
  );
}
