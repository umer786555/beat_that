import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/upload_category/models/upload_category.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'upload_category_event.dart';
import 'upload_category_state.dart';

class UploadCategoryBloc
    extends Bloc<UploadCategoryEvent, UploadCategoryState> {
  final SupabaseService _supabaseService = locator<SupabaseService>();

  UploadCategoryBloc() : super(const UploadCategoryInitial()) {
    on<FetchUploadCategoryImagesEvent>(_onFetchUploadCategoryImages);
    on<RetryUploadCategoryImagesEvent>(_onRetryUploadCategoryImages);
  }

  Future<void> _onFetchUploadCategoryImages(
    FetchUploadCategoryImagesEvent event,
    Emitter<UploadCategoryState> emit,
  ) async {
    emit(const UploadCategoryLoading());

    try {
      final categories = [
        for (final imageUrl in _supabaseService.getCategoryImages())
          ?UploadCategory.fromImageUrl(imageUrl),
      ];

      if (categories.isEmpty) {
        emit(const UploadCategoryError(message: AppStrings.noUploadCategories));
        return;
      }

      emit(UploadCategoryLoaded(categories: categories));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        const UploadCategoryError(
          message: AppStrings.somethingWentWrongPleaseTryAgain,
        ),
      );
    }
  }

  Future<void> _onRetryUploadCategoryImages(
    RetryUploadCategoryImagesEvent event,
    Emitter<UploadCategoryState> emit,
  ) async {
    await _onFetchUploadCategoryImages(
      const FetchUploadCategoryImagesEvent(),
      emit,
    );
  }
}
