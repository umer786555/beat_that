import 'package:beat_that/models/sport_video.dart';
import 'package:equatable/equatable.dart';

class ExploreVideoFeedState extends Equatable {
  static const Object _sentinel = Object();

  final List<SportVideo> videos;
  final int currentIndex;
  final int nextOffset;
  final bool hasMoreContent;
  final bool isRandomFeed;
  final String? randomSeed;
  final String? randomAfterId;
  final bool randomHasWrapped;
  final bool isLoadingMore;
  final String? errorMessage;
  final int? currentUserRating;
  final bool isSubmittingRating;

  const ExploreVideoFeedState({
    required this.videos,
    required this.currentIndex,
    required this.nextOffset,
    required this.hasMoreContent,
    this.isRandomFeed = false,
    this.randomSeed,
    this.randomAfterId,
    this.randomHasWrapped = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentUserRating,
    this.isSubmittingRating = false,
  });

  ExploreVideoFeedState copyWith({
    List<SportVideo>? videos,
    int? currentIndex,
    int? nextOffset,
    bool? hasMoreContent,
    bool? isRandomFeed,
    Object? randomSeed = _sentinel,
    Object? randomAfterId = _sentinel,
    bool? randomHasWrapped,
    bool? isLoadingMore,
    String? errorMessage,
    Object? currentUserRating = _sentinel,
    bool? isSubmittingRating,
    bool clearErrorMessage = false,
  }) {
    return ExploreVideoFeedState(
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      nextOffset: nextOffset ?? this.nextOffset,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isRandomFeed: isRandomFeed ?? this.isRandomFeed,
      randomSeed: identical(randomSeed, _sentinel)
          ? this.randomSeed
          : randomSeed as String?,
      randomAfterId: identical(randomAfterId, _sentinel)
          ? this.randomAfterId
          : randomAfterId as String?,
      randomHasWrapped: randomHasWrapped ?? this.randomHasWrapped,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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
    isRandomFeed,
    randomSeed,
    randomAfterId,
    randomHasWrapped,
    isLoadingMore,
    errorMessage,
    currentUserRating,
    isSubmittingRating,
  ];
}
