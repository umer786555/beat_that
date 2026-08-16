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

final class HomeVideoFeedReportSuccessEvent
    extends HomeVideoFeedPresentationEvent {
  HomeVideoFeedReportSuccessEvent(this.message);

  final String message;
}

final class HomeVideoFeedReportErrorEvent
    extends HomeVideoFeedPresentationEvent {
  HomeVideoFeedReportErrorEvent(this.message);

  final String message;
}
