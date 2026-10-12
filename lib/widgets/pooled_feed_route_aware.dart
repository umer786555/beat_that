import 'package:beat_that/bloc/pooled_feed_playback.dart';
import 'package:beat_that/service_locator.dart';
import 'package:flutter/widgets.dart';

/// Pauses a pooled feed while another page covers it.
///
/// Bottom sheets and dialogs are popup routes, not page routes, so they leave
/// playback alone.
mixin PooledFeedRouteAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  late final RouteObserver<PageRoute<dynamic>> _routeObserver =
      locator<RouteObserver<PageRoute<dynamic>>>();

  PooledFeedPlayback<Object?> get feedPlayback;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => feedPlayback.onRouteCovered();

  @override
  void didPopNext() => feedPlayback.onRouteUncovered();

  @override
  void didPush() {}

  @override
  void didPop() {}
}
