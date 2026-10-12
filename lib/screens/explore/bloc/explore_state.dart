part of 'explore_bloc.dart';

sealed class ExploreState extends Equatable {
  const ExploreState({
    this.filterCatalog = const ExploreFilterCatalog.empty(),
    this.selectedFilterId,
  });

  final ExploreFilterCatalog filterCatalog;
  final String? selectedFilterId;

  @override
  List<Object?> get props => [filterCatalog, selectedFilterId ?? ''];
}

final class ExploreInitial extends ExploreState {
  const ExploreInitial({super.filterCatalog, super.selectedFilterId});
}

final class ExploreLoading extends ExploreState {
  const ExploreLoading({
    required this.query,
    super.filterCatalog,
    super.selectedFilterId,
  });

  final String query;

  @override
  List<Object?> get props => [filterCatalog, selectedFilterId ?? '', query];
}

final class ExploreLoaded extends ExploreState {
  static const Object _sentinel = Object();

  const ExploreLoaded({
    required this.query,
    required this.videos,
    required this.totalCount,
    required this.hasMore,
    required this.nextOffset,
    super.filterCatalog,
    super.selectedFilterId,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.isRandomFeed = false,
    this.randomSeed,
    this.randomAfterId,
    this.randomHasWrapped = false,
  });

  final String query;
  final List<SportVideo> videos;
  final int totalCount;
  final bool hasMore;
  final int nextOffset;
  final bool isLoadingMore;

  /// Stops scrolling from re-triggering a failed page until the user retries.
  final bool loadMoreFailed;
  final bool isRandomFeed;
  final String? randomSeed;
  final String? randomAfterId;
  final bool randomHasWrapped;

  ExploreLoaded copyWith({
    ExploreFilterCatalog? filterCatalog,
    String? query,
    String? selectedFilterId,
    List<SportVideo>? videos,
    int? totalCount,
    bool? hasMore,
    int? nextOffset,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    bool? isRandomFeed,
    Object? randomSeed = _sentinel,
    Object? randomAfterId = _sentinel,
    bool? randomHasWrapped,
  }) {
    return ExploreLoaded(
      filterCatalog: filterCatalog ?? this.filterCatalog,
      query: query ?? this.query,
      selectedFilterId: selectedFilterId ?? this.selectedFilterId,
      videos: videos ?? this.videos,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      isRandomFeed: isRandomFeed ?? this.isRandomFeed,
      randomSeed: identical(randomSeed, _sentinel)
          ? this.randomSeed
          : randomSeed as String?,
      randomAfterId: identical(randomAfterId, _sentinel)
          ? this.randomAfterId
          : randomAfterId as String?,
      randomHasWrapped: randomHasWrapped ?? this.randomHasWrapped,
    );
  }

  @override
  List<Object?> get props => [
    filterCatalog,
    selectedFilterId ?? '',
    query,
    videos,
    totalCount,
    hasMore,
    nextOffset,
    isLoadingMore,
    loadMoreFailed,
    isRandomFeed,
    randomSeed,
    randomAfterId,
    randomHasWrapped,
  ];
}

final class ExploreError extends ExploreState {
  const ExploreError({
    required this.message,
    required this.query,
    super.filterCatalog,
    super.selectedFilterId,
  });

  final String message;
  final String query;

  @override
  List<Object?> get props => [
    filterCatalog,
    selectedFilterId ?? '',
    message,
    query,
  ];
}
