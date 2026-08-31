sealed class HomeVideoFeedPresentationEvent {}

final class HomeVideoFeedRatingSuccessEvent
    extends HomeVideoFeedPresentationEvent {
  HomeVideoFeedRatingSuccessEvent(this.message);

  final String message;
}

final class HomeVideoFeedRatingErrorEvent
    extends HomeVideoFeedPresentationEvent {
  HomeVideoFeedRatingErrorEvent(this.message);

  final String message;
}
