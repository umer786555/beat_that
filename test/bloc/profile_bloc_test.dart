import 'dart:async';
import 'dart:io';

import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

class MockPermissionService extends Mock implements PermissionService {}

class MockSupabaseService extends Mock implements SupabaseService {}

class MockPreferencesService extends Mock implements PreferencesService {}

class MockVideoPickerService extends Mock implements VideoPickerService {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPermissionService mockPermissionService;
  late MockSupabaseService mockSupabaseService;
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

  ProfileBloc buildBloc() {
    final bloc = ProfileBloc(
      supabaseService: mockSupabaseService,
      preferencesService: mockPreferencesService,
      permissionService: mockPermissionService,
      videoPickerService: mockVideoPickerService,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  Future<ProfileLoaded> seedLoadedState(ProfileBloc bloc) async {
    bloc.add(const LoadProfileEvent());
    return await bloc.stream.firstWhere(
          (state) => state is ProfileLoaded && state.deletingVideoId == null,
        )
        as ProfileLoaded;
  }

  setUpAll(() {
    registerFallbackValue(File(''));
  });

  setUp(() {
    mockPermissionService = MockPermissionService();
    mockSupabaseService = MockSupabaseService();
    mockPreferencesService = MockPreferencesService();
    mockVideoPickerService = MockVideoPickerService();

    when(
      () => mockPreferencesService.fetchUserProfile(),
    ).thenAnswer((_) async => UserPersonalProfile(username: 'tester'));
  });

  group('ProfileBloc load flow', () {
    test('emits a generic error when the first load fails', () async {
      when(
        () => mockSupabaseService.getMyVideo(),
      ).thenAnswer((_) async => throw Exception('socket closed'));

      final bloc = buildBloc()..add(const LoadProfileEvent());

      final errorState =
          await bloc.stream.firstWhere((state) => state is ProfileError)
              as ProfileError;

      expect(errorState.message, AppStrings.failedToLoadProfile);
    });

    test('keeps the profile on screen while refreshing', () async {
      final videoResponses = <List<MyVideo>>[
        [makeVideo('video-1')],
        [makeVideo('video-1'), makeVideo('video-2')],
      ];
      when(
        () => mockSupabaseService.getMyVideo(),
      ).thenAnswer((_) async => videoResponses.removeAt(0));

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(const LoadProfileEvent());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && !state.isRefreshing,
      );

      expect(states, everyElement(isA<ProfileLoaded>()));
      expect((states.first as ProfileLoaded).isRefreshing, isTrue);
      expect((bloc.state as ProfileLoaded).myVideos, hasLength(2));
    });

    test(
      'keeps the profile and reports an error when a refresh fails',
      () async {
        var calls = 0;
        when(() => mockSupabaseService.getMyVideo()).thenAnswer((_) async {
          calls++;
          if (calls > 1) {
            throw Exception('timeout');
          }
          return [makeVideo('video-1')];
        });

        final bloc = buildBloc();
        await seedLoadedState(bloc);

        final presentation = bloc.presentation.first;
        bloc.add(const LoadProfileEvent());

        final event = await presentation;
        expect(event, isA<ProfileErrorMessageEvent>());
        expect(event.message, AppStrings.failedToRefreshProfile);

        final state = bloc.state as ProfileLoaded;
        expect(state.isRefreshing, isFalse);
        expect(state.myVideos.single.id, 'video-1');
      },
    );

    test(
      'a load failing after a concurrent load succeeded keeps the profile',
      () async {
        final firstLoad = Completer<List<MyVideo>>();
        final secondLoad = Completer<List<MyVideo>>();
        final responses = [firstLoad, secondLoad];
        when(
          () => mockSupabaseService.getMyVideo(),
        ).thenAnswer((_) => responses.removeAt(0).future);

        final bloc = buildBloc()
          ..add(const LoadProfileEvent())
          ..add(const LoadProfileEvent());
        await pumpEventQueue();

        firstLoad.complete([makeVideo('video-1')]);
        await bloc.stream.firstWhere((state) => state is ProfileLoaded);

        final presentation = bloc.presentation.first;
        secondLoad.completeError(Exception('timeout'));

        expect((await presentation).message, AppStrings.failedToRefreshProfile);
        expect(bloc.state, isA<ProfileLoaded>());
      },
    );
  });

  group('ProfileBloc profile image flow', () {
    setUp(() {
      when(
        () => mockSupabaseService.getMyVideo(),
      ).thenAnswer((_) async => [makeVideo('video-1')]);
      when(
        () => mockPermissionService.requestPhotosAccess(),
      ).thenAnswer((_) async => true);
      when(
        () => mockVideoPickerService.pickGalleryPhoto(),
      ).thenAnswer((_) async => XFile('/tmp/photo.jpg'));
    });

    test('uploads in place and updates the profile url', () async {
      final updatedProfile = UserPersonalProfile(
        username: 'tester',
        profileUrl: 'https://example.com/new.jpg',
      );
      when(
        () => mockSupabaseService.uploadAndSaveProfileImage(any(), 'tester'),
      ).thenAnswer((_) async => {'success': true});
      when(
        () => mockSupabaseService.fetchUserPersonalProfile(),
      ).thenAnswer((_) async => updatedProfile);
      when(
        () => mockPreferencesService.saveUserProfile(updatedProfile),
      ).thenAnswer((_) async {});

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(const AddProfileImageEvent());
      await bloc.stream.firstWhere(
        (state) =>
            state is ProfileLoaded &&
            state.profileUrl == updatedProfile.profileUrl,
      );

      expect(states, everyElement(isA<ProfileLoaded>()));
      expect((states.first as ProfileLoaded).isUploadingProfileImage, isTrue);
      expect((bloc.state as ProfileLoaded).isUploadingProfileImage, isFalse);
      verify(
        () => mockPreferencesService.saveUserProfile(updatedProfile),
      ).called(1);
    });

    test('reports an upload failure without leaving the profile', () async {
      when(
        () => mockSupabaseService.uploadAndSaveProfileImage(any(), any()),
      ).thenAnswer((_) async => {'success': false, 'error': 'quota'});

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      final presentation = bloc.presentation.first;
      bloc.add(const AddProfileImageEvent());

      final event = await presentation;
      expect(event, isA<ProfileErrorMessageEvent>());
      expect(event.message, AppStrings.failedToUpdateProfilePhoto);
      expect((bloc.state as ProfileLoaded).isUploadingProfileImage, isFalse);
    });

    test('reports missing photo access without opening the picker', () async {
      when(
        () => mockPermissionService.requestPhotosAccess(),
      ).thenAnswer((_) async => false);

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      final presentation = bloc.presentation.first;
      bloc.add(const AddProfileImageEvent());

      expect((await presentation).message, AppStrings.photoAccessRequired);
      verifyNever(() => mockVideoPickerService.pickGalleryPhoto());
    });

    test('ignores a second tap while the picker is open', () async {
      final pickerCompleter = Completer<XFile?>();
      when(
        () => mockVideoPickerService.pickGalleryPhoto(),
      ).thenAnswer((_) => pickerCompleter.future);

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      bloc.add(const AddProfileImageEvent());
      await untilCalled(() => mockVideoPickerService.pickGalleryPhoto());
      bloc.add(const AddProfileImageEvent());
      await pumpEventQueue();

      verify(() => mockPermissionService.requestPhotosAccess()).called(1);

      pickerCompleter.complete(null);
      await pumpEventQueue();
    });

    test('does nothing when the user cancels the picker', () async {
      when(
        () => mockVideoPickerService.pickGalleryPhoto(),
      ).thenAnswer((_) async => null);

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(const AddProfileImageEvent());
      await pumpEventQueue();

      expect(states, isEmpty);
      verifyNever(
        () => mockSupabaseService.uploadAndSaveProfileImage(any(), any()),
      );
    });
  });

  group('ProfileBloc delete flow', () {
    test(
      'ignores a second delete request while the first delete is in flight',
      () async {
        final deleteCompleter = Completer<Map<String, dynamic>>();

        when(
          () => mockSupabaseService.getMyVideo(),
        ).thenAnswer((_) async => [makeVideo('video-1'), makeVideo('video-2')]);
        when(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        ).thenAnswer((_) => deleteCompleter.future);

        final bloc = buildBloc();
        await seedLoadedState(bloc);

        bloc.add(const DeleteVideoEvent(videoId: 'video-1'));
        await untilCalled(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        );

        expect((bloc.state as ProfileLoaded).deletingVideoId, 'video-1');

        bloc.add(const DeleteVideoEvent(videoId: 'video-2'));
        await pumpEventQueue();

        verifyNever(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-2',
          ),
        );

        final presentation = bloc.presentation.first;
        deleteCompleter.complete({'success': true});

        final finalState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded &&
                      state.deletingVideoId == null &&
                      state.myVideos.length == 1,
                )
                as ProfileLoaded;

        expect(finalState.myVideos.single.id, 'video-2');
        expect((await presentation).message, AppStrings.videoDeleted);
      },
    );

    test(
      'preserves newer loaded state when a delete fails after an approval update',
      () async {
        final deleteCompleter = Completer<Map<String, dynamic>>();

        when(() => mockSupabaseService.getMyVideo()).thenAnswer(
          (_) async => [
            makeVideo('video-1', approved: true),
            makeVideo('video-2', approved: true),
          ],
        );
        when(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        ).thenAnswer((_) => deleteCompleter.future);

        final bloc = buildBloc();
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
              state.myVideos[1].approved == false,
        );

        final presentation = bloc.presentation.first;
        deleteCompleter.complete({'success': false, 'error': 'boom'});

        final finalState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded && state.deletingVideoId == null,
                )
                as ProfileLoaded;

        expect(finalState.myVideos, hasLength(2));
        expect(finalState.myVideos[1].approved, isFalse);
        expect((await presentation).message, AppStrings.failedToDeleteVideo);
      },
    );

    test(
      'a videos refresh that finishes mid-delete keeps the delete in progress',
      () async {
        final refreshCompleter = Completer<List<MyVideo>>();
        final deleteCompleter = Completer<Map<String, dynamic>>();
        var calls = 0;

        when(() => mockSupabaseService.getMyVideo()).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future.value([makeVideo('video-1'), makeVideo('video-2')]);
          }
          return refreshCompleter.future;
        });
        when(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        ).thenAnswer((_) => deleteCompleter.future);

        final bloc = buildBloc();
        await seedLoadedState(bloc);
        clearInteractions(mockSupabaseService);

        bloc.add(const RefreshVideosEvent());
        await untilCalled(() => mockSupabaseService.getMyVideo());

        bloc.add(const DeleteVideoEvent(videoId: 'video-1'));
        await untilCalled(
          () => mockSupabaseService.deleteMyVideoViaEdgeFunction(
            videoId: 'video-1',
          ),
        );

        refreshCompleter.complete([
          makeVideo('video-1'),
          makeVideo('video-2'),
          makeVideo('video-3'),
        ]);

        final refreshedState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded && state.myVideos.length == 3,
                )
                as ProfileLoaded;

        expect(refreshedState.deletingVideoId, 'video-1');
      },
    );
  });

  group('ProfileBloc videos refresh', () {
    test('updates the videos and reports failures in place', () async {
      var calls = 0;
      when(() => mockSupabaseService.getMyVideo()).thenAnswer((_) async {
        calls++;
        return switch (calls) {
          1 => [makeVideo('video-1')],
          2 => [makeVideo('video-1'), makeVideo('video-2')],
          _ => throw Exception('timeout'),
        };
      });

      final bloc = buildBloc();
      await seedLoadedState(bloc);

      bloc.add(const RefreshVideosEvent());
      await bloc.stream.firstWhere(
        (state) => state is ProfileLoaded && state.myVideos.length == 2,
      );

      final presentation = bloc.presentation.first;
      bloc.add(const RefreshVideosEvent());

      expect((await presentation).message, AppStrings.failedToRefreshVideos);
      expect((bloc.state as ProfileLoaded).myVideos, hasLength(2));
    });
  });

  group('ProfileBloc approval updates', () {
    late MockRealtimeChannel mockChannel;
    late void Function(String videoId, bool? approvalStatus) onApprovalChanged;

    setUp(() {
      mockChannel = MockRealtimeChannel();
      when(() => mockChannel.unsubscribe()).thenAnswer((_) async => 'ok');
      when(
        () => mockSupabaseService.subscribeToVideoApprovalChanges(
          onApprovalChanged: any(named: 'onApprovalChanged'),
        ),
      ).thenAnswer((invocation) {
        onApprovalChanged =
            invocation.namedArguments[#onApprovalChanged]
                as void Function(String, bool?);
        return mockChannel;
      });
    });

    test(
      'subscribes while a video is pending and unsubscribes once resolved',
      () async {
        when(
          () => mockSupabaseService.getMyVideo(),
        ).thenAnswer((_) async => [makeVideo('video-1', approved: null)]);

        final bloc = buildBloc();
        await seedLoadedState(bloc);

        // A second load must reuse the open channel.
        bloc.add(const LoadProfileEvent());
        await bloc.stream.firstWhere(
          (state) => state is ProfileLoaded && !state.isRefreshing,
        );
        verify(
          () => mockSupabaseService.subscribeToVideoApprovalChanges(
            onApprovalChanged: any(named: 'onApprovalChanged'),
          ),
        ).called(1);

        onApprovalChanged('video-1', true);
        final approvedState =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is ProfileLoaded &&
                      state.myVideos.single.approved == true,
                )
                as ProfileLoaded;

        expect(approvedState.myVideos.single.id, 'video-1');
        await untilCalled(() => mockChannel.unsubscribe());
      },
    );

    test('unsubscribes when the bloc closes', () async {
      when(
        () => mockSupabaseService.getMyVideo(),
      ).thenAnswer((_) async => [makeVideo('video-1', approved: null)]);

      final bloc = buildBloc();
      await seedLoadedState(bloc);
      await pumpEventQueue();

      await bloc.close();

      verify(() => mockChannel.unsubscribe()).called(1);
    });

    test('ignores updates for videos that are not in the list', () async {
      when(
        () => mockSupabaseService.getMyVideo(),
      ).thenAnswer((_) async => [makeVideo('video-1')]);

      final bloc = buildBloc();
      await seedLoadedState(bloc);
      clearInteractions(mockSupabaseService);

      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(
        const VideoApprovalUpdatedEvent(
          videoId: 'someone-elses-video',
          approvalStatus: true,
        ),
      );
      await pumpEventQueue();

      expect(states, isEmpty);
      verifyNever(() => mockSupabaseService.getMyVideo());
    });
  });
}
