---
title: "refactor: ExploreBloc single state with typed ExploreRepository"
type: refactor
date: 2026-10-13
---

## refactor: ExploreBloc single state with typed ExploreRepository - Standard

Part 2 of 3. See the [umbrella plan](2026-10-13-refactor-explore-screen-polish-plan.md).

## Dependencies

- **Part 1 must be merged first.** This part updates the sliver-based `explore_screen.dart` and its widget tests from Part 1.
- Branch: `refactor/explore-bloc-repository`, created from `main` after Part 1 merges.

## Overview

Move `ExploreBloc` onto flutter_bloc best practices:

- one immutable `ExploreState` with a status enum;
- a sealed `ExploreCursor`;
- a constructor-injected `ExploreRepository` that returns a typed `ExplorePage` and throws on failure;
- `bloc_concurrency` transformers in place of the widget's `Timer` / `_submittedQuery` and the bloc's `_searchGeneration`.

This also fixes a real bug: a failed search currently shows "No matching videos" instead of the error state.

## Problem Statement / Motivation

- **Search errors are swallowed.** [supabase_service.dart:1139](../../lib/services/supabase_service.dart#L1139) catches every error and returns an empty result, so a failed search reaches `NoResultsState`.
- **The sealed states don't hold disjoint data.** `filterCatalog`, `selectedFilterId` and `query` survive every transition, so `_withFilterCatalog` ([explore_bloc.dart:336](../../lib/screens/explore/bloc/explore_bloc.dart#L336)) rebuilds all four subclasses. `ExploreLoaded.copyWith` needs a sentinel, and `selectedFilterId ?? ''` in `props` treats null and `''` as equal.
- **Five loose cursor fields** (`nextOffset`, `isRandomFeed`, `randomSeed`, `randomAfterId`, `randomHasWrapped`).
- **Hand-rolled concurrency:** the widget's `Timer` debounce plus `_submittedQuery`, and the bloc's `_searchGeneration` counter.
- **Hidden dependencies:** the bloc reads `locator<SupabaseService>()`, and handlers call `add()` on the bloc itself (refresh and retry).

## Proposed Solution

### 1. Throwing search method: `lib/services/supabase_service.dart`

```dart
// lib/services/supabase_service.dart
/// Runs `search_explore_videos`; throws on RPC or mapping failure.
Future<({List<SportVideo> videos, int totalCount})> searchExploreVideos({
  required String query,
  String? sportId,
  int limit = 20,
  int offset = 0,
}) async { /* RPC + _buildSportVideosFromRows, no try/catch */ }

Future<Map<String, dynamic>> searchVideosByTitle(...) async {
  // keeps the empty-query early return; try { await searchExploreVideos(...) → old map }
  // catch → old empty map. Behaviour for ExploreVideoFeedCubit unchanged.
}
```

`getRandomExploreVideos` stays as it is. The repository turns its `error` / `errorCode` map entries into throws.

### 2. Models: `lib/models/explore_page.dart` (new)

```dart
// lib/models/explore_page.dart
sealed class ExploreCursor extends Equatable { const ExploreCursor(); }

/// Fully describes the next search request, so value equality also matches query and sport.
final class SearchCursor extends ExploreCursor {
  const SearchCursor({required this.query, this.sportId, required this.offset});
  final String query; final String? sportId; final int offset;
  @override List<Object?> get props => [query, sportId, offset];
}

final class RandomCursor extends ExploreCursor {
  const RandomCursor({required this.seed, this.afterId, this.hasWrapped = false});
  final String seed; final String? afterId; final bool hasWrapped;
  @override List<Object?> get props => [seed, afterId, hasWrapped];
}

class ExplorePage extends Equatable {
  const ExplorePage({required this.videos, required this.cursor, required this.hasMore, this.totalCount});
  final List<SportVideo> videos; final ExploreCursor cursor; final bool hasMore;
  final int? totalCount; // search mode only
  @override List<Object?> get props => [videos, cursor, hasMore, totalCount];
}
```

`SearchCursor` carries `query` and `sportId`, so the load-more stale check (`state.cursor != requestCursor`) can't confuse two searches that both stop at `offset: 20`. A page for the **same** query and offset is valid data, and appending it is correct. `RandomCursor` gets a fresh seed for every search.

### 3. Repository: `lib/repositories/explore_repository.dart` (new)

```dart
// lib/repositories/explore_repository.dart
class ExploreRepository {
  ExploreRepository({required SupabaseService supabaseService, String Function()? seedSource})
    : _supabaseService = supabaseService, _seedSource = seedSource ?? _defaultSeed;

  static const int pageSize = 20;

  Future<List<ExploreFilterSourceRow>> getFilters();           // pass-through
  Future<ExplorePage> search({required String query, String? sportId}); // first page
  Future<ExplorePage> loadMore(ExploreCursor cursor);          // next page
}

/// Thrown when `getRandomExploreVideos` reports an `error` entry.
class ExploreException implements Exception {
  const ExploreException(this.message, {this.code});
  final String message; final String? code;
}
```

`searchExploreVideos` exceptions are **not** wrapped; they propagate unchanged. The bloc catches every failure and calls `addError(error, stackTrace)` so diagnostics aren't lost.

- `search` sends empty `query` with no `sportId` to the random feed with `RandomCursor(seed: _seedSource())`. Anything else goes to `searchExploreVideos` from offset 0. A comment notes that this rule must match `ExploreState.isRandomFeed`.
- `loadMore` switches on the cursor type.
- It owns the **stale-cursor reset**: on `errorCode == '22023'` when `afterId != null || hasWrapped`, it calls again with the same seed from the top (moved from [explore_bloc.dart:88](../../lib/screens/explore/bloc/explore_bloc.dart#L88)).
- Any other `error` entry from `getRandomExploreVideos` becomes an `ExploreException(message, code:)`.
- `_defaultSeed` is today's `'${microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}'`.
- Registered in [service_locator.dart](../../lib/service_locator.dart) next to `HomeFeedService`: `locator.registerSingleton<ExploreRepository>(ExploreRepository(supabaseService: locator<SupabaseService>()))`.

### 4. State: `lib/screens/explore/bloc/explore_state.dart`

```dart
// lib/screens/explore/bloc/explore_state.dart
enum ExploreStatus { initial, loading, success, failure }
enum ExploreLoadMoreStatus { idle, loading, failure }

final class ExploreState extends Equatable {
  const ExploreState({
    required this.filterCatalog,
    this.status = ExploreStatus.initial,
    this.query = '',
    this.selectedFilterId,
    this.videos = const [],
    this.cursor,
    this.hasMore = false,
    this.totalCount,
    this.loadMoreStatus = ExploreLoadMoreStatus.idle,
  });
  …
  bool get isRandomFeed => query.isEmpty && selectedFilterId == null;
  ExploreState copyWith({…}); // non-null updates only; no sentinel
}
```

- **No sentinel.** A new search builds a fresh `ExploreState(filterCatalog: state.filterCatalog, status: loading, query:, selectedFilterId:)`, which naturally resets `cursor`, `totalCount`, `videos` and `loadMoreStatus`. `copyWith` is only used for non-null updates.
- `isRandomFeed` is derived from query and filter, so it is defined during loading and failure too, when there is no cursor.

### 5. Events: `lib/screens/explore/bloc/explore_event.dart`

```dart
// lib/screens/explore/bloc/explore_event.dart
sealed class ExploreEvent extends Equatable {
  const ExploreEvent();
  @override List<Object?> get props => []; // Object?: null and '' are no longer equal
}

final class ExploreFiltersRequested extends ExploreEvent { const ExploreFiltersRequested(); }

/// Every subtype carries the field's current text, so a search that cancels
/// a pending debounce still uses what the user sees.
sealed class ExploreSearchRequested extends ExploreEvent { const ExploreSearchRequested({required this.query}); final String query; }
final class ExploreQueryChanged extends ExploreSearchRequested { const ExploreQueryChanged({required super.query}); }   // debounced
final class ExploreFilterSelected extends ExploreSearchRequested { const ExploreFilterSelected({required super.query, this.filterId}); final String? filterId; }
final class ExploreRefreshRequested extends ExploreSearchRequested { const ExploreRefreshRequested({required super.query}); } // pull, retry, initial load

final class ExploreLoadMoreRequested extends ExploreEvent { const ExploreLoadMoreRequested({this.isRetry = false}); final bool isRetry; }

/// The full-screen feed handed back the list it reached.
final class ExploreFeedProgressReceived extends ExploreEvent { const ExploreFeedProgressReceived(this.progress); final ExploreFeedProgress progress; }
```

All subclasses override `props` with their fields.

### 6. Bloc: `lib/screens/explore/bloc/explore_bloc.dart`

```dart
// lib/screens/explore/bloc/explore_bloc.dart
ExploreBloc({
  required ExploreRepository exploreRepository,
  Locale? locale,
  Duration searchDebounce = const Duration(milliseconds: 500), // tests pass a short value
}) : … {
  on<ExploreFiltersRequested>(_onFiltersRequested);
  on<ExploreSearchRequested>(_onSearchRequested, transformer: restartable());
  on<ExploreLoadMoreRequested>(_onLoadMoreRequested, transformer: droppable());
  on<ExploreFeedProgressReceived>(_onFeedProgressReceived);
}
```

**Rule for every handler:** `ExploreFiltersRequested` runs alongside searches. So any state built **after an `await`** reads `state.filterCatalog` at that moment, never a copy saved before the `await`. Otherwise a slow search would write the fallback catalog back over the backend one.

**`_onSearchRequested`** (runs inside `restartable()`, so a new event has already cancelled the previous handler):

1. `query = _effectiveQuery(event.query)`. The rule (fewer than 3 trimmed characters means browse) is private to the bloc. `filterId` comes from the event for `ExploreFilterSelected`, otherwise from `state.selectedFilterId` (trimmed, empty becomes null).
2. **Duplicate check, inside the handler:** for `ExploreQueryChanged` and `ExploreFilterSelected`, return if `query == state.query && filterId == state.selectedFilterId && state.status == ExploreStatus.success`. Refresh always runs.
   - The check runs after `restartable()`. Clearing the field while "abc" is debouncing cancels the "abc" search, and the clear is then correctly ignored because nothing was emitted.
   - **Only `success` counts as a duplicate.** A `loading` state means the search that emitted it may just have been cancelled by `restartable()`. Skipping a matching event then would leave the screen stuck in `loading`. Example: during the first load, type "abc" and then clear; the clear must re-run the browse search.
3. **Debounce:** for `ExploreQueryChanged` with non-empty `query`, run `await Future.delayed(_searchDebounce); if (emit.isDone) return;`. **Nothing is emitted before the delay**, so the old grid stays visible while the user types.
4. **Emit loading:**
   - a refresh of the same query and filter emits `state.copyWith(status: loading)`, which **keeps the videos** so the grid stays under the refresh spinner;
   - anything else emits a fresh state with `status: loading` and empty videos, which shows the skeleton.
5. `page = await _exploreRepository.search(query:, sportId:)`, then emit a fresh `success` state built from the page and the **current** `state.filterCatalog`.
   - On any error, call `addError(e, st)`, then emit `status: failure` and keep `query` and filter, with no message string.
   - A failed same-query refresh replaces the grid with the error state. This is intended: the user explicitly asked for fresh data.

**`_onLoadMoreRequested`** (`droppable()`):

- Return unless `status == success && hasMore && (loadMoreStatus == idle || (loadMoreStatus == failure && event.isRetry))`.
- `requestCursor = state.cursor!`, then emit `loadMoreStatus: loading`.
- After `loadMore(requestCursor)`, **`if (state.cursor != requestCursor) return;`**. This drops a page belonging to a replaced search. A new search builds a fresh state with `loadMoreStatus: idle`, so nothing is left in `loading`.
- Append the videos deduped by id, take `cursor`, `hasMore`, and `totalCount ?? state.totalCount`, and set `loadMoreStatus: idle`. On an exception, run the same stale check, then set `loadMoreStatus: failure`.

**`_onFeedProgressReceived`:**

- Return unless `status == success && loadMoreStatus != loading` and query, filter, mode and seed (`(cursor as RandomCursor?)?.seed` against `progress.randomSeed`) match, the progress is longer, and the current list is a prefix of it.
- Skipping a merge during an in-flight load-more matches today's behaviour, and it is rare.
- Rebuild the cursor from the progress, and set `loadMoreStatus: idle`:
  - random: `RandomCursor(seed, afterId, hasWrapped)`;
  - search: `SearchCursor(query, filter, nextOffset)`.

**`_onFiltersRequested`:** emit `state.copyWith(filterCatalog: …)`, and keep the fallback on any error. `_withFilterCatalog` is deleted.

Handlers never call `add()`.

### 7. Screen: `lib/screens/explore/explore_screen.dart`

- `BlocProvider(create: (_) => ExploreBloc(exploreRepository: locator<ExploreRepository>(), locale: …)..add(ExploreFiltersRequested())..add(const ExploreRefreshRequested(query: '')))`.
- **Remove** `_debounce`, `_submittedQuery`, `_searchDebounce`, `dart:async` and the calls to `ExploreBloc.effectiveQuery`. `onChanged` adds `ExploreQueryChanged(query: value)`. A filter tap adds `ExploreFilterSelected(query: _searchController.text, filterId:)`. Clear adds `ExploreQueryChanged(query: '')`.
- The slivers switch on `state.status`:
  - `initial`, or `loading` with no videos: skeleton;
  - `failure`: `ExploreErrorState(message: _kExploreErrorMessage)`, a friendly fixed string such as "Couldn't load videos. Check your connection and try again.";
  - `success` with no videos: empty or no-results;
  - otherwise the grid. `loadMoreStatus` drives the skeleton and retry slivers.
- **Refresh completion:**

  ```dart
  // lib/screens/explore/explore_screen.dart
  final done = bloc.stream
      .skipWhile((s) => s.status != ExploreStatus.loading)
      .firstWhere((s) => s.status != ExploreStatus.loading);
  bloc.add(ExploreRefreshRequested(query: _searchController.text));
  await done.then((_) {}, onError: (_) {}); // bloc closed → StateError
  ```

  The `skipWhile` stops the future from completing early on a catalog or merge emission that happens before the handler emits `loading`.
- **Scroll to top:** the Part 1 `BlocListener` becomes `listenWhen: (p, c) => c.status == loading && c.videos.isEmpty`, so a same-query refresh doesn't jump.
- **Feed extra:** a small private `_toFeedExtra(state, index)` flattens the cursor into `ExploreVideoFeedExtra`:
  - `nextOffset` from `SearchCursor.offset`, or `0`;
  - random fields from `RandomCursor`;
  - `isRandomFeed: state.isRandomFeed`, so the "random feed" rule lives in one place.
- The merge call site adds `ExploreFeedProgressReceived(progress)`.
- `_revealVideo.shouldContinue` checks `state.status == ExploreStatus.success && index < state.videos.length`.
- `ExploreEmptyState`'s "Search Videos" default (the old `ExploreInitial` branch) is no longer used. Remove the unused default copy.

### 8. Dependency: `pubspec.yaml`

Add `bloc_concurrency` (latest compatible with `flutter_bloc: ^9.1.1`; `flutter pub add bloc_concurrency`). `stream_transform` is not needed.

## Technical Considerations

- **Architecture:** the repository layer starts at `lib/repositories/`. The bloc depends only on `ExploreRepository`, and the repository depends on `SupabaseService`. Dependencies point one way.
- **Unchanged contract:** `ExploreVideoFeedCubit`, `ExploreVideoFeedExtra`, `ExploreFeedProgress` and `ExploreFeedProgressStore` don't change. `searchVideosByTitle` behaves exactly as before.
- **Droppable trade-off:** while a stale load-more is in flight, the new search's first load-more is dropped. The next scroll event triggers it again, which is acceptable.
- **Error copy:** one generic friendly message. Telling offline apart from server errors is out of scope.

## Tests

- [ ] `test/repositories/explore_repository_test.dart` (new; `MockSupabaseService`, fixed `seedSource: () => 'seed-1'`):
  - empty query with no sport calls `getRandomExploreVideos(seed: 'seed-1')` and maps it to `ExplorePage` with a `RandomCursor`;
  - a query or sport calls `searchExploreVideos(offset: 0)` and maps to a `SearchCursor` with `totalCount` and `hasMore`;
  - `loadMore(SearchCursor)` and `loadMore(RandomCursor)` pass the cursor fields through;
  - `errorCode '22023'` with an `afterId` retries from the top with the same seed and returns that page;
  - `22023` on a reset that fails again, or any other `error`, throws `ExploreException`;
  - an exception from `searchExploreVideos` propagates unchanged.
- [ ] `test/models/explore_page_test.dart` (new; follows `test/models/home_feed_cursor_test.dart`):
  - `SearchCursor(query: 'a', offset: 20) != SearchCursor(query: 'b', offset: 20)`;
  - a `sportId` difference also makes cursors unequal;
  - equal fields give equal cursors;
  - `RandomCursor` equality covers all three fields.
- [ ] `test/bloc/explore_bloc_test.dart` (rewrite; `MockExploreRepository` via the constructor, `searchDebounce: Duration(milliseconds: 50)`, **no `locator`**). It covers:
  - filters requested updates the catalog, and an error keeps the fallback;
  - **catalog during a search:** filters resolve while `search` is pending (`Completer`); the final `success` state keeps the backend catalog;
  - initial `ExploreRefreshRequested('')` goes `[loading, success]` with a random cursor;
  - **debounce:** `ExploreQueryChanged('abc')` makes no repository call before the debounce and one call after;
  - **restart:** `'abc'` then `'abcd'` inside the debounce cause exactly one `search(query: 'abcd')`;
  - **clear during debounce:** from `success`, `'abc'` then `''` cause no search call, and the state is unchanged;
  - **no stuck loading:** during the initial load (`search` pending on a `Completer`), `'abc'` then `''` end in `success` for browse, with `search(query: '')` called again;
  - a duplicate query or filter is ignored in `success` and runs again after a `failure`;
  - a query shorter than 3 characters behaves as browse (`search(query: '')`);
  - a `filterId` of `''` or `'  '` becomes null;
  - `ExploreFilterSelected` searches immediately with no delay;
  - **refresh with a pending debounce:** `QueryChanged('abc')` then `RefreshRequested('abc')` cause one immediate `search(query: 'abc')`;
  - **refresh keeps videos** in the `loading` state for the same query, and a failed refresh emits `failure`;
  - **dropped duplicate load-more:** two `ExploreLoadMoreRequested` cause one `loadMore` call;
  - **stale load-more:** load-more of A/20 in flight, then a search for B returning B/20, then A's page resolves. B's videos are untouched and `loadMoreStatus` is idle;
  - load-more failure gives `loadMoreStatus: failure`; a non-retry event is ignored, and `isRetry: true` loads;
  - **search failure** gives `status: failure` with query and filter kept (this is the bug fix), and `addError` is recorded (`errors:`);
  - **progress received:** extends the matching prefix; ignored on a query, seed or prefix mismatch; ignored while `loading` or during a load-more.
- [ ] `test/screens/explore/explore_screen_test.dart`: register a `MockExploreRepository` in `locator` instead of `SupabaseService`. Keep the Part 1 assertions, and add:
  - a failed search shows `ExploreErrorState` with the friendly copy, not `NoResultsState`;
  - the refresh future completes after a same-query refresh, and the grid stays visible during it.
- [ ] `test/screens/explore/video_feed/*`: unchanged and still green.

## Implementation Phases

Both phases land in **one PR**; each phase is one commit.

### Phase 1: Format baseline and data layer

- **Status:** Not started
- **Scope:**
  - **Format-only commit first:** run `dart format` on `explore_bloc.dart`, `explore_event.dart` and `supabase_service.dart`, which are unformatted on `main`.
  - Then add `searchExploreVideos` (with `searchVideosByTitle` wrapping it), `explore_page.dart`, `ExploreRepository` and its `service_locator` registration, and the `bloc_concurrency` dependency.
  - The bloc doesn't use any of this yet, so the app still behaves exactly as before.
- **Files touched:** `lib/services/supabase_service.dart`, `lib/models/explore_page.dart`, `lib/repositories/explore_repository.dart`, `lib/service_locator.dart`, `pubspec.yaml`, `pubspec.lock`, `test/models/explore_page_test.dart`, `test/repositories/explore_repository_test.dart`
- **Acceptance criteria:** the repository and model tests pass, and the existing suite is unchanged and green.
- **Validation:** `flutter test test/repositories test/models && flutter test`

### Phase 2: Single-state bloc and screen rewiring

- **Status:** Not started
- **Scope:** Rewrite `ExploreState`, the events and `ExploreBloc` on the repository. Rewire `explore_screen.dart` (remove the debounce, switch on status, wire the refresh completion, add `_toFeedExtra`), then rewrite the bloc test and update the screen test.
- **Files touched:** `lib/screens/explore/bloc/explore_bloc.dart`, `lib/screens/explore/bloc/explore_state.dart`, `lib/screens/explore/bloc/explore_event.dart`, `lib/screens/explore/explore_screen.dart`, `lib/screens/explore/video_feed/widgets/explore_empty_state.dart`, `test/bloc/explore_bloc_test.dart`, `test/screens/explore/explore_screen_test.dart`
- **Acceptance criteria:** every Success Criteria command passes.
- **Validation:** the VERIFICATION COMMAND below.

## Success Criteria

```success-criteria
GOAL: ExploreBloc uses one immutable ExploreState with a status enum and sealed ExploreCursor, gets data from a constructor-injected ExploreRepository that throws on failure, and replaces the hand-rolled debounce/generation logic with bloc_concurrency, so search failures reach the error state.

SUCCESS CRITERIA:
- Repository maps pages, resets stale random cursors and throws on failure | verify: flutter test test/repositories/explore_repository_test.dart
- Cursors distinguish searches that stop at the same offset | verify: flutter test test/models/explore_page_test.dart
- Bloc covers debounce, restart, clear-during-debounce, duplicate drop, dropped load-more, stale load-more, failure and merge paths without locator | verify: flutter test test/bloc/explore_bloc_test.dart && ! grep -q "locator" test/bloc/explore_bloc_test.dart
- A failed search shows the error state, not "No matching videos" | verify: flutter test test/screens/explore/explore_screen_test.dart
- ExploreBloc has no service-locator lookup, self-dispatch (receiver-less add) or generation counter | verify: ! grep -qE "locator|_searchGeneration|[^.a-zA-Z0-9_]add\(" lib/screens/explore/bloc/explore_bloc.dart
- The widget no longer debounces or tracks submitted queries | verify: ! grep -qE "\bTimer\b|_submittedQuery|effectiveQuery" lib/screens/explore/explore_screen.dart
- Single state class, no sentinel copyWith or _withFilterCatalog | verify: ! grep -qE "_sentinel|_withFilterCatalog|class (ExploreLoaded|ExploreLoading|ExploreError|ExploreInitial)\b" lib/screens/explore/bloc/explore_state.dart lib/screens/explore/bloc/explore_bloc.dart
- bloc_concurrency is a dependency and both transformers are used | verify: grep -q "^  bloc_concurrency:" pubspec.yaml && grep -q "restartable()" lib/screens/explore/bloc/explore_bloc.dart && grep -q "droppable()" lib/screens/explore/bloc/explore_bloc.dart
- Full-screen feed contract unchanged | verify: flutter test test/screens/explore/video_feed && git diff --quiet $(git merge-base main HEAD) -- lib/screens/explore/video_feed/explore_video_feed_cubit.dart lib/screens/explore/video_feed/explore_video_feed_route_extra.dart lib/services/explore_feed_progress_store.dart
- Touched code is analyzer-clean (supabase_service.dart: no new errors/warnings beyond the pre-existing unawaited_return_in_try_block) and formatted | verify: flutter analyze lib/screens/explore lib/repositories lib/models/explore_page.dart lib/service_locator.dart test/repositories test/models test/bloc/explore_bloc_test.dart test/screens/explore && ! (flutter analyze lib/services/supabase_service.dart 2>&1 | grep -E "^\s*(error|warning) " | grep -v unawaited_return_in_try_block) && dart format --output=none --set-exit-if-changed $(git diff --name-only --diff-filter=d $(git merge-base main HEAD) -- '*.dart')
- Full suite stays green | verify: flutter test
- Search, refresh and failure behave correctly on device | verify: manual 1. Type "bas" slowly then quickly to "basket": only one network search fires after typing stops (check logs / network inspector). 2. Type "abc" then clear within half a second: grid stays on browse, no search fires. 3. Pull to refresh in search mode: the existing grid stays visible under the indicator until results replace it. 4. Enable airplane mode, type a query: the error state with friendly copy appears (not "No matching videos"); disable airplane mode, tap Retry: results load. 5. Scroll to trigger load-more, then immediately change chip: the new results are not polluted by the old query's page. 6. Open a card, scroll several pages in the feed, return: grid includes the extra videos and reveals the card. 7. In the full-screen feed in search mode, enable airplane mode and swipe to trigger the feed's load-more: it degrades exactly as before (no new error UI), confirming searchVideosByTitle's swallow behaviour is unchanged.

NON-GOALS:
- Moving ExploreVideoFeedCubit / ExploreFeedProgress onto ExploreRepository / ExploreCursor (follow-up)
- Changing searchVideosByTitle's swallow-errors behaviour for the feed cubit
- Distinguishing offline vs server errors in copy
- Keyboard "Search" submit skipping the debounce
- Reconciling an unknown selectedFilterId after the backend catalog loads

VERIFICATION COMMAND: flutter test && ! grep -q "locator" test/bloc/explore_bloc_test.dart && ! grep -qE "locator|_searchGeneration|[^.a-zA-Z0-9_]add\(" lib/screens/explore/bloc/explore_bloc.dart && ! grep -qE "\bTimer\b|_submittedQuery|effectiveQuery" lib/screens/explore/explore_screen.dart && ! grep -qE "_sentinel|_withFilterCatalog|class (ExploreLoaded|ExploreLoading|ExploreError|ExploreInitial)\b" lib/screens/explore/bloc/explore_state.dart lib/screens/explore/bloc/explore_bloc.dart && grep -q "^  bloc_concurrency:" pubspec.yaml && grep -q "restartable()" lib/screens/explore/bloc/explore_bloc.dart && grep -q "droppable()" lib/screens/explore/bloc/explore_bloc.dart && git diff --quiet $(git merge-base main HEAD) -- lib/screens/explore/video_feed/explore_video_feed_cubit.dart lib/screens/explore/video_feed/explore_video_feed_route_extra.dart lib/services/explore_feed_progress_store.dart && flutter analyze lib/screens/explore lib/repositories lib/models/explore_page.dart lib/service_locator.dart test/repositories test/models test/bloc/explore_bloc_test.dart test/screens/explore && ! (flutter analyze lib/services/supabase_service.dart 2>&1 | grep -E "^\s*(error|warning) " | grep -v unawaited_return_in_try_block) && dart format --output=none --set-exit-if-changed $(git diff --name-only --diff-filter=d $(git merge-base main HEAD) -- '*.dart')
```

## Success Metrics

- Search failures surface as errors. "No matching videos" now means zero results.
- No stale results after rapid typing or chip changes.
- About 100 fewer lines across `explore_bloc.dart` and `explore_state.dart`.

## Dependencies & Risks

- **Depends on:** Part 1 merged.
- **Risk: `restartable()` plus `Future.delayed` in tests.** The `searchDebounce` constructor parameter keeps the bloc tests fast (50 ms) and deterministic with `blocTest(wait:)`.
- **Risk: the self-dispatch grep.** `[^.a-zA-Z0-9_]add\(` matches a receiver-less `add(` and not `List.add`. It was checked against BSD grep: it finds today's 4 self-dispatch calls.
- **Risk: concurrent filters and search.** The "read `state.filterCatalog` after `await`" rule, plus its test.
- **Risk: equality pitfalls.** `SearchCursor` includes `query` and `sportId`, which covers the value-equal cursor case. There is an explicit test for it.

## References & Research

- Current bloc: [explore_bloc.dart](../../lib/screens/explore/bloc/explore_bloc.dart), state: [explore_state.dart](../../lib/screens/explore/bloc/explore_state.dart)
- Swallowing search: [supabase_service.dart:1139](../../lib/services/supabase_service.dart#L1139); random feed with `errorCode`: [:1073](../../lib/services/supabase_service.dart#L1073)
- Sibling single-state pattern: `ExploreVideoFeedCubit` / `explore_video_feed_state.dart`, `HomeVideoFeedState`
- Service pattern: [home_feed_service.dart](../../lib/services/home_feed_service.dart); registration: [service_locator.dart:92](../../lib/service_locator.dart#L92)
- bloc_concurrency: https://pub.dev/packages/bloc_concurrency
