sealed class ExploreVideoFeedPresentationEvent {}

final class ExploreVideoFeedRatingSuccessEvent
    extends ExploreVideoFeedPresentationEvent {
  ExploreVideoFeedRatingSuccessEvent(this.message);

  final String message;
}

final class ExploreVideoFeedRatingErrorEvent
    extends ExploreVideoFeedPresentationEvent {
  ExploreVideoFeedRatingErrorEvent(this.message);

  final String message;
}
