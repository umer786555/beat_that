import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabaseService;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(mockSupabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  blocTest<ExploreBloc, ExploreState>(
    'refreshes the current loaded search from bloc state',
    setUp: () {
      when(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          exactMatch: false,
          startsWithOnly: false,
          sportId: 'tennis',
        ),
      ).thenAnswer(
        (_) async => {
          'videos': [
            {
              'id': 'video-1',
              'title': 'Baseline drill',
              'thumbnail_url': 'https://example.com/thumb1.jpg',
              'username': 'coach1',
            },
          ],
          'totalCount': 1,
          'hasMore': false,
          'nextOffset': 1,
        },
      );
    },
    build: () => ExploreBloc(),
    seed: () => const ExploreLoaded(
      query: '',
      searchMode: ExploreSearchMode.soft,
      selectedSportId: 'tennis',
      videos: [],
      totalCount: 0,
      hasMore: false,
      nextOffset: 0,
    ),
    act: (bloc) => bloc.add(const RefreshExploreVideosEvent()),
    expect: () => [
      const ExploreLoading(
        query: '',
        searchMode: ExploreSearchMode.soft,
        selectedSportId: 'tennis',
      ),
      isA<ExploreLoaded>()
          .having((state) => state.selectedSportId, 'selectedSportId', 'tennis')
          .having((state) => state.videos.length, 'videos length', 1),
    ],
    verify: (_) {
      verify(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          exactMatch: false,
          startsWithOnly: false,
          sportId: 'tennis',
        ),
      ).called(1);
    },
  );
}
