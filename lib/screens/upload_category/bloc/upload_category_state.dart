import 'package:beat_that/screens/upload_category/models/upload_category.dart';

sealed class UploadCategoryState {
  const UploadCategoryState();
}

class UploadCategoryInitial extends UploadCategoryState {
  const UploadCategoryInitial();
}

class UploadCategoryLoading extends UploadCategoryState {
  const UploadCategoryLoading();
}

class UploadCategoryLoaded extends UploadCategoryState {
  final List<UploadCategory> categories;

  const UploadCategoryLoaded({required this.categories});
}

class UploadCategoryError extends UploadCategoryState {
  final String message;

  const UploadCategoryError({required this.message});
}
