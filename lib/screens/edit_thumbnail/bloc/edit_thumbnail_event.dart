part of 'edit_thumbnail_bloc.dart';

sealed class EditThumbnailEvent extends Equatable {
  const EditThumbnailEvent();

  @override
  List<Object> get props => [];
}

final class InitialEvent extends EditThumbnailEvent {
  const InitialEvent();
}

final class ThumbnailSelectedEvent extends EditThumbnailEvent {
  final int selectedIndex;

  const ThumbnailSelectedEvent({required this.selectedIndex});

  @override
  List<Object> get props => [selectedIndex];
}
