import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_bloc.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_event.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_state.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

const _bucketUrl =
    'https://example.supabase.co/storage/v1/object/public/upload_categories';

Matcher isError(String message) =>
    isA<UploadCategoryError>().having((s) => s.message, 'message', message);

void main() {
  late MockSupabaseService supabaseService;

  setUp(() {
    supabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(supabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  group('UploadCategoryBloc', () {
    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'maps category images to categories in order',
      setUp: () {
        when(
          () => supabaseService.getCategoryImages(),
        ).thenReturn(['$_bucketUrl/gaming.png', '$_bucketUrl/sports.png']);
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const FetchUploadCategoryImagesEvent()),
      expect: () => [
        isA<UploadCategoryLoading>(),
        isA<UploadCategoryLoaded>().having(
          (state) => [
            for (final c in state.categories)
              (c.id, c.title, c.routeName, c.imageUrl),
          ],
          'categories',
          [
            (
              'gaming',
              AppStrings.gaming,
              'gaming-hub',
              '$_bucketUrl/gaming.png',
            ),
            (
              'sports',
              AppStrings.sports,
              'sports-hub',
              '$_bucketUrl/sports.png',
            ),
          ],
        ),
      ],
    );

    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'skips images with no matching category',
      setUp: () {
        when(
          () => supabaseService.getCategoryImages(),
        ).thenReturn(['$_bucketUrl/cooking.png', '$_bucketUrl/sports.png']);
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const FetchUploadCategoryImagesEvent()),
      expect: () => [
        isA<UploadCategoryLoading>(),
        isA<UploadCategoryLoaded>().having(
          (state) => state.categories.map((c) => c.id),
          'ids',
          ['sports'],
        ),
      ],
    );

    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'emits the no-categories error when nothing matches',
      setUp: () {
        when(
          () => supabaseService.getCategoryImages(),
        ).thenReturn(['$_bucketUrl/cooking.png']);
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const FetchUploadCategoryImagesEvent()),
      expect: () => [
        isA<UploadCategoryLoading>(),
        isError(AppStrings.noUploadCategories),
      ],
    );

    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'emits the no-categories error when there are no images',
      setUp: () {
        when(() => supabaseService.getCategoryImages()).thenReturn([]);
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const FetchUploadCategoryImagesEvent()),
      expect: () => [
        isA<UploadCategoryLoading>(),
        isError(AppStrings.noUploadCategories),
      ],
    );

    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'emits generic copy and reports the error when loading fails',
      setUp: () {
        when(
          () => supabaseService.getCategoryImages(),
        ).thenThrow(Exception('storage down'));
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const FetchUploadCategoryImagesEvent()),
      expect: () => [
        isA<UploadCategoryLoading>(),
        isError(AppStrings.somethingWentWrongPleaseTryAgain),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<UploadCategoryBloc, UploadCategoryState>(
      'retry fetches the categories again',
      setUp: () {
        when(
          () => supabaseService.getCategoryImages(),
        ).thenReturn(['$_bucketUrl/sports.png']);
      },
      build: UploadCategoryBloc.new,
      act: (bloc) => bloc.add(const RetryUploadCategoryImagesEvent()),
      expect: () => [isA<UploadCategoryLoading>(), isA<UploadCategoryLoaded>()],
      verify: (_) =>
          verify(() => supabaseService.getCategoryImages()).called(1),
    );
  });
}
