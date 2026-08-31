import 'package:equatable/equatable.dart';

class HomeFeedCursor extends Equatable {
  const HomeFeedCursor({
    this.personalizedOffset = 0,
    this.followingOffset = 0,
    this.trendingOffset = 0,
    this.hasMorePersonalized = true,
    this.hasMoreFollowing = true,
    this.hasMoreTrending = true,
    this.hasMoreDiscovery = true,
  });

  const HomeFeedCursor.initial()
    : personalizedOffset = 0,
      followingOffset = 0,
      trendingOffset = 0,
      hasMorePersonalized = true,
      hasMoreFollowing = true,
      hasMoreTrending = true,
      hasMoreDiscovery = true;

  final int personalizedOffset;
  final int followingOffset;
  final int trendingOffset;
  final bool hasMorePersonalized;
  final bool hasMoreFollowing;
  final bool hasMoreTrending;
  final bool hasMoreDiscovery;

  bool get hasMoreContent =>
      hasMorePersonalized ||
      hasMoreFollowing ||
      hasMoreTrending ||
      hasMoreDiscovery;

  HomeFeedCursor copyWith({
    int? personalizedOffset,
    int? followingOffset,
    int? trendingOffset,
    bool? hasMorePersonalized,
    bool? hasMoreFollowing,
    bool? hasMoreTrending,
    bool? hasMoreDiscovery,
  }) {
    return HomeFeedCursor(
      personalizedOffset: personalizedOffset ?? this.personalizedOffset,
      followingOffset: followingOffset ?? this.followingOffset,
      trendingOffset: trendingOffset ?? this.trendingOffset,
      hasMorePersonalized: hasMorePersonalized ?? this.hasMorePersonalized,
      hasMoreFollowing: hasMoreFollowing ?? this.hasMoreFollowing,
      hasMoreTrending: hasMoreTrending ?? this.hasMoreTrending,
      hasMoreDiscovery: hasMoreDiscovery ?? this.hasMoreDiscovery,
    );
  }

  @override
  List<Object> get props => [
    personalizedOffset,
    followingOffset,
    trendingOffset,
    hasMorePersonalized,
    hasMoreFollowing,
    hasMoreTrending,
    hasMoreDiscovery,
  ];
}