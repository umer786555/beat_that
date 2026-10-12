abstract class UploadCategoryEvent {
  const UploadCategoryEvent();
}

class FetchUploadCategoryImagesEvent extends UploadCategoryEvent {
  const FetchUploadCategoryImagesEvent();
}

class RetryUploadCategoryImagesEvent extends UploadCategoryEvent {
  const RetryUploadCategoryImagesEvent();
}
