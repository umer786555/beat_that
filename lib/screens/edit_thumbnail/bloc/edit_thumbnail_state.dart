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

  const ThumbnailsGeneratedState({required this.thumbnails, this.isLoading = false, this.selectedIndex});

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

final class ThumbnailErrorState extends EditThumbnailState {
  final String message;

  const ThumbnailErrorState({required this.message});

  @override
  List<Object> get props => [message];
}
