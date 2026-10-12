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
      final imageUrls = _supabaseService.getCategoryImages();

      if (imageUrls.isEmpty) {
        emit(
          const UploadCategoryError(
            message: 'No upload categories are available right now.',
          ),
        );
        return;
      }

      emit(UploadCategoryLoaded(imageUrls: imageUrls));
    } catch (e) {
      emit(
        UploadCategoryError(message: 'Failed to load upload categories: $e'),
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
