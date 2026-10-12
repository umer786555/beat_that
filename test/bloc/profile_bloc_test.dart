import 'dart:async';

import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPermissionService extends Mock implements PermissionService {}

class MockSupabaseService extends Mock implements SupabaseService {}

class MockAuthService extends Mock implements AuthService {}

class MockPreferencesService extends Mock implements PreferencesService {}

class MockVideoPickerService extends Mock implements VideoPickerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPermissionService mockPermissionService;
  late MockSupabaseService mockSupabaseService;
  late MockAuthService mockAuthService;
  late MockPreferencesService mockPreferencesService;
  late MockVideoPickerService mockVideoPickerService;

  MyVideo makeVideo(String id, {bool? approved = true}) {
    return MyVideo(
      id: id,
      createdAt: '2026-01-01T00:00:00Z',
      userId: 'user-1',
      title: 'Video $id',
      videoPath: '$id.mp4',
      thumbnailPath: '$id.jpg',
      thumbnailUrl: 'https://example.com/$id.jpg',
      approved: approved,
    );
  }

  Future<void> seedLoadedState(ProfileBloc bloc) async {
    bloc.add(const LoadProfileEvent());
    await bloc.stream.firstWhere(
      (state) => state is ProfileLoaded && state.deletingVideoId == null,
    );
  }

  setUp(() {
    mockPermissionService = MockPermissionService();
    mockSupabaseService = MockSupabaseService();
    mockAuthService = MockAuthService();
    mockPreferencesService = MockPreferencesService();
    mockVideoPickerService = MockVideoPickerService();

    locator.registerSingleton<PermissionService>(mockPermissionService);
    locator.registerSingleton<SupabaseService>(mockSupabaseService);
    locator.registerSingleton<AuthService>(mockAuthService);
    locator.registerSingleton<PreferencesService>(mockPreferencesService);
    locator.registerSingleton<VideoPickerService>(mockVideoPickerService);

    when(
      () => mockPermissionService.checkCameraPermissionOnLoad(),
    ).thenAnswer((_) async => true);
    when(
      () => mockPermissionService.checkPhotosPermissionOnLoad(),
    ).thenAnswer((_) async => true);
    when(
      () => mockPreferencesService.fetchUserProfile(),
    ).thenAnswer((_) async => UserPersonalProfile(username: 'tester'));
  });

  tearDown(() async {
    await locator.reset();
  });

  group('ProfileBloc delete flow', () {
    test(
      'ignores a second delete request while the first delete is in flight',
      () async {
        final deleteCompleter = Completer<Map<String, dynamic>>();
        final getMyVideoResponses = <List<MyVideo>>[
          [makeVideo('video-1'), makeVideo('video-2')],
          [makeVideo('video-2')],
        ];

        when(
          () => mockSupabaseService.getMyVideo(),
        ).thenAnswer((_) async => getMyVideoResponses.removeAt(0));
        when(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        ).thenAnswer((_) => deleteCompleter.future);

        final bloc = ProfileBloc();
        addTearDown(bloc.close);

        await seedLoadedState(bloc);

        bloc.add(const DeleteVideoEvent(videoId: 'video-1'));
        await untilCalled(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        );

        expect((bloc.state as ProfileLoaded).deletingVideoId, 'video-1');

        bloc.add(const DeleteVideoEvent(videoId: 'video-2'));
        await Future<void>.value();

        verifyNever(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-2',
          ),
        );

        deleteCompleter.complete({'success': true});

        final finalState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded &&
                      state.deletingVideoId == null &&
                      state.myVideo.length == 1,
                )
                as ProfileLoaded;

        expect(finalState.myVideo.single.id, 'video-2');
      },
    );

    test(
      'preserves newer loaded state when a delete fails after an approval update',
      () async {
        final deleteCompleter = Completer<Map<String, dynamic>>();
        final initialVideos = [
          makeVideo('video-1', approved: true),
          makeVideo('video-2', approved: true),
        ];

        when(
          () => mockSupabaseService.getMyVideo(),
        ).thenAnswer((_) async => initialVideos);
        when(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        ).thenAnswer((_) => deleteCompleter.future);

        final bloc = ProfileBloc();
        addTearDown(bloc.close);

        await seedLoadedState(bloc);

        bloc.add(const DeleteVideoEvent(videoId: 'video-1'));
        await untilCalled(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        );

        bloc.add(
          const VideoApprovalUpdatedEvent(
            videoId: 'video-2',
            approvalStatus: false,
          ),
        );

        await bloc.stream.firstWhere(
          (state) =>
              state is ProfileLoaded &&
              state.deletingVideoId == 'video-1' &&
              state.myVideo[1].approved == false,
        );

        deleteCompleter.complete({'success': false, 'error': 'boom'});

        final finalState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded && state.deletingVideoId == null,
                )
                as ProfileLoaded;

        expect(finalState.myVideo[1].approved, isFalse);
      },
    );
  });
}
