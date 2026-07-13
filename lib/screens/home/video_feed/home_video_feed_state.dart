import 'package:equatable/equatable.dart';

class HomeVideoFeedState extends Equatable {
  final List<Map<String, dynamic>> videos;
  final int currentIndex;
  final int nextOffset;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final int controllerGeneration;
  final String? errorMessage;

  const HomeVideoFeedState({
    required this.videos,
    required this.currentIndex,
    required this.nextOffset,
    required this.hasMoreContent,
    this.isLoadingMore = false,
    this.controllerGeneration = 0,
    this.errorMessage,
  });

  HomeVideoFeedState copyWith({
    List<Map<String, dynamic>>? videos,
    int? currentIndex,
    int? nextOffset,
    bool? hasMoreContent,
    bool? isLoadingMore,
    int? controllerGeneration,
    String? errorMessage,
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
  ];
}
