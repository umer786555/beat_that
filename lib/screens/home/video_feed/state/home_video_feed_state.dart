import 'package:equatable/equatable.dart';

class HomeVideoFeedState extends Equatable {
  static const Object _sentinel = Object();

  final List<Map<String, dynamic>> videos;
  final int currentIndex;
  final int nextOffset;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final int controllerGeneration;
  final String? errorMessage;
  final int? currentUserRating;
  final bool isSubmittingRating;

  const HomeVideoFeedState({
    required this.videos,
    required this.currentIndex,
    required this.nextOffset,
    required this.hasMoreContent,
    this.isLoadingMore = false,
    this.controllerGeneration = 0,
    this.errorMessage,
    this.currentUserRating,
    this.isSubmittingRating = false,
  });

  HomeVideoFeedState copyWith({
    List<Map<String, dynamic>>? videos,
    int? currentIndex,
    int? nextOffset,
    bool? hasMoreContent,
    bool? isLoadingMore,
    int? controllerGeneration,
    String? errorMessage,
    Object? currentUserRating = _sentinel,
    bool? isSubmittingRating,
    bool clearErrorMessage = false,
  }) {
    return HomeVideoFeedState(
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      nextOffset: nextOffset ?? this.nextOffset,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      controllerGeneration: controllerGeneration ?? this.controllerGeneration,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      currentUserRating: identical(currentUserRating, _sentinel)
          ? this.currentUserRating
          : currentUserRating as int?,
      isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
    );
  }

  @override
  List<Object?> get props => [
    videos,
    currentIndex,
    nextOffset,
    hasMoreContent,
    isLoadingMore,
    controllerGeneration,
    errorMessage,
    currentUserRating,
    isSubmittingRating,
  ];
}
