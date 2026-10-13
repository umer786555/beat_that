import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/screens/gaming_hub/bloc/gaming_hub_bloc.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

CategoryModel game(String displayName) => CategoryModel(
  id: displayName,
  name: displayName.toLowerCase(),
  displayName: displayName,
  subcategories: const [],
);

void main() {
  late MockSupabaseService supabaseService;

  setUp(() {
    supabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(supabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  group('GamingHubBloc', () {
    blocTest<GamingHubBloc, GamingHubState>(
      'loads games sorted alphabetically with Other Games last',
      setUp: () {
        when(() => supabaseService.fetchGames()).thenAnswer(
          (_) async => [
            game('Valorant'),
            game('Other Games'),
            game('apex Legends'),
            game('Fortnite'),
          ],
        );
      },
      build: GamingHubBloc.new,
      act: (bloc) => bloc.add(const LoadGamingHubEvent()),
      expect: () => [
        isA<GamingHubLoading>(),
        isA<GamingHubLoaded>().having(
          (state) => state.games.map((game) => game.displayName),
          'game names',
          ['apex Legends', 'Fortnite', 'Valorant', 'Other Games'],
        ),
      ],
    );

    blocTest<GamingHubBloc, GamingHubState>(
      'emits generic copy and reports the error when loading fails',
      setUp: () {
        when(
          () => supabaseService.fetchGames(),
        ).thenThrow(Exception('network down'));
      },
      build: GamingHubBloc.new,
      act: (bloc) => bloc.add(const LoadGamingHubEvent()),
      expect: () => [
        isA<GamingHubLoading>(),
        const GamingHubError(AppStrings.somethingWentWrongPleaseTryAgain),
      ],
      errors: () => [isA<Exception>()],
    );
  });
}
