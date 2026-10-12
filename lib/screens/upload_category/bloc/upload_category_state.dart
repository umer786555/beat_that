abstract class UploadCategoryState {
  const UploadCategoryState();
}

class UploadCategoryInitial extends UploadCategoryState {
  const UploadCategoryInitial();
}

class UploadCategoryLoading extends UploadCategoryState {
  const UploadCategoryLoading();
}

class UploadCategoryLoaded extends UploadCategoryState {
  final List<String> imageUrls;

  const UploadCategoryLoaded({required this.imageUrls});
}

class UploadCategoryError extends UploadCategoryState {
  final String message;

  const UploadCategoryError({required this.message});
}
