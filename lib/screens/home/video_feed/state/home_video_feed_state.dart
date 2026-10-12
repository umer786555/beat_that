import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:equatable/equatable.dart';

class HomeVideoFeedState extends Equatable {
  static const Object _sentinel = Object();

  final List<SportVideo> videos;
  final int currentIndex;
  final HomeFeedCursor nextCursor;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final String? errorMessage;
  final int? currentUserRating;
  final bool isSubmittingRating;

  const HomeVideoFeedState({
    required this.videos,
    required this.currentIndex,
    required this.nextCursor,
    required this.hasMoreContent,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentUserRating,
    this.isSubmittingRating = false,
  });

  HomeVideoFeedState copyWith({
    List<SportVideo>? videos,
    int? currentIndex,
    HomeFeedCursor? nextCursor,
    bool? hasMoreContent,
    bool? isLoadingMore,
    String? errorMessage,
    Object? currentUserRating = _sentinel,
    bool? isSubmittingRating,
    bool clearErrorMessage = false,
  }) {
    return HomeVideoFeedState(
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
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
    nextCursor,
    hasMoreContent,
    isLoadingMore,
    errorMessage,
    currentUserRating,
    isSubmittingRating,
  ];
}
