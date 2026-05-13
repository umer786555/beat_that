part of 'edit_thumbnail_bloc.dart';

/// Presentation events for one-time side effects like showing snackbars or dialogs
sealed class EditThumbnailPresentationEvent {}

/// Emitted when an error occurs during thumbnail generation or upload
final class ThumbnailErrorEvent extends EditThumbnailPresentationEvent {
  final String message;

  ThumbnailErrorEvent({required this.message});
}

/// Emitted when video upload succeeds - shows snack bar and pops screen
final class SaveSuccessEvent extends EditThumbnailPresentationEvent {
  final String message;

  SaveSuccessEvent({required this.message});
}
