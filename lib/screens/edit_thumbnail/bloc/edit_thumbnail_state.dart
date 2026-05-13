part of 'edit_thumbnail_bloc.dart';

sealed class EditThumbnailState extends Equatable {
  const EditThumbnailState();

  @override
  List<Object> get props => [];
}

final class EditThumbnailInitial extends EditThumbnailState {}

final class ThumbnailsGeneratedState extends EditThumbnailState {
  final List<Uint8List> thumbnails;
  final bool isLoading;
  final int? selectedIndex;

  const ThumbnailsGeneratedState({
    required this.thumbnails,
    this.isLoading = false,
    this.selectedIndex,
  });

  @override
  List<Object> get props => [thumbnails, isLoading, selectedIndex ?? -1];

  ThumbnailsGeneratedState copyWith({
    List<Uint8List>? thumbnails,
    bool? isLoading,
    int? selectedIndex,
  }) {
    return ThumbnailsGeneratedState(
      thumbnails: thumbnails ?? this.thumbnails,
      isLoading: isLoading ?? this.isLoading,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

final class SavingVideoState extends EditThumbnailState {
  final String message;

  const SavingVideoState({required this.message});

  @override
  List<Object> get props => [message];
}

final class VideoUploadProgressState extends EditThumbnailState {
  final int sentBytes;
  final int totalBytes;
  final int progressPercent;

  const VideoUploadProgressState({
    required this.sentBytes,
    required this.totalBytes,
    required this.progressPercent,
  });

  @override
  List<Object> get props => [sentBytes, totalBytes, progressPercent];
}

final class ThumbnailErrorState extends EditThumbnailState {
  final String message;

  const ThumbnailErrorState({required this.message});

  @override
  List<Object> get props => [message];
}
