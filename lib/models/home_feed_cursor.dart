import 'package:equatable/equatable.dart';

/// Continuation token for one Home feed session.
///
/// The client only reads the per-source exhaustion flags. Everything else
/// (keyset positions, frozen tracked subcategories, trending window) lives in
/// [serverState] and is sent back to `get_home_feed_page_v2` unchanged.
class HomeFeedCursor extends Equatable {
  const HomeFeedCursor({
    this.hasMorePersonalized = true,
    this.hasMoreFollowing = true,
    this.hasMoreTrending = true,
    this.hasMoreDiscovery = true,
    this.serverState = const <String, dynamic>{},
  });

  const HomeFeedCursor.initial()
    : hasMorePersonalized = true,
      hasMoreFollowing = true,
      hasMoreTrending = true,
      hasMoreDiscovery = true,
      serverState = const <String, dynamic>{};

  static const String _hasMorePersonalizedKey = 'hasMorePersonalized';
  static const String _hasMoreFollowingKey = 'hasMoreFollowing';
  static const String _hasMoreTrendingKey = 'hasMoreTrending';
  static const String _hasMoreDiscoveryKey = 'hasMoreDiscovery';

  final bool hasMorePersonalized;
  final bool hasMoreFollowing;
  final bool hasMoreTrending;
  final bool hasMoreDiscovery;

  /// Opaque server-owned cursor fields.
  final Map<String, dynamic> serverState;

  bool get hasMoreContent =>
      hasMorePersonalized ||
      hasMoreFollowing ||
      hasMoreTrending ||
      hasMoreDiscovery;

  factory HomeFeedCursor.fromMap(Map<String, dynamic> map) {
    return HomeFeedCursor(
      hasMorePersonalized: map[_hasMorePersonalizedKey] as bool? ?? true,
      hasMoreFollowing: map[_hasMoreFollowingKey] as bool? ?? true,
      hasMoreTrending: map[_hasMoreTrendingKey] as bool? ?? true,
      hasMoreDiscovery: map[_hasMoreDiscoveryKey] as bool? ?? true,
      serverState: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.of(map)..removeWhere(
          (key, _) =>
              key == _hasMorePersonalizedKey ||
              key == _hasMoreFollowingKey ||
              key == _hasMoreTrendingKey ||
              key == _hasMoreDiscoveryKey,
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...serverState,
      _hasMorePersonalizedKey: hasMorePersonalized,
      _hasMoreFollowingKey: hasMoreFollowing,
      _hasMoreTrendingKey: hasMoreTrending,
      _hasMoreDiscoveryKey: hasMoreDiscovery,
    };
  }

  @override
  List<Object> get props => [
    hasMorePersonalized,
    hasMoreFollowing,
    hasMoreTrending,
    hasMoreDiscovery,
    serverState,
  ];
}