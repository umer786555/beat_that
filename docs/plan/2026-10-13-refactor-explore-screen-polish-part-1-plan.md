---
title: "feat: explore visual pass with shimmer skeletons and floating header"
type: feat
date: 2026-10-13
---

## feat: explore visual pass with shimmer skeletons and floating header - Standard

Part 1 of 3. See the [umbrella plan](2026-10-13-refactor-explore-screen-polish-plan.md).

## Overview

Visual pass on the Explore grid, built on the **current** `ExploreBloc` with no state or event changes:

- Shimmer skeletons replace the first-load spinner and the flat grey load-more boxes.
- Thumbnails show a theme-aware shimmer placeholder, fade in on first frame, and use a themed error tile.
- The search pill, expanded search bar and sport chips become a `SliverFloatingHeader` in one `CustomScrollView`.
- Grid geometry lives in one place, and Home switches to the same skeleton sliver.

Branch: `refactor/explore-screen-polish` (current).

## Problem Statement / Motivation

- First load shows a bare `CircularProgressIndicator` ([explore_screen.dart:187](../../lib/screens/explore/explore_screen.dart#L187)). Load-more shows flat `SearchLoadingCard` boxes with a different corner radius (20, against the cards' 12).
- The thumbnail placeholder is a light-only `0xFFCDD3DD` box ([video_feed_card.dart:77](../../lib/widgets/video_feed_card.dart#L77)), and the error tile is a hard-coded `0xFF323846`.
- The header is fixed in a `Column`. Chips take permanent vertical space, and the empty and error states use a separate `SingleChildScrollView` path (`_buildRefreshableBody`).
- Grid geometry (`2 / 6 / 6 / 0.64`) is repeated at `explore_screen.dart:341`, `:428`, `home_screen.dart:286`, `:374`, and in the `estimateFeedGridOffset` defaults ([feed_grid_reveal.dart:42](../../lib/widgets/feed_grid_reveal.dart#L42)).
- Two skeleton grids exist: `ShimmerLoading` (8 px, 9/14, shrink-wrapped `GridView`) and Home's inline `_buildLoadingSliver`.

## Proposed Solution

### 1. Shared grid geometry: `lib/widgets/feed_grid_geometry.dart` (new)

```dart
// lib/widgets/feed_grid_geometry.dart
const double kFeedGridSpacing = 6;
const double kFeedGridChildAspectRatio = 0.64;

/// Delegate shared by Home and Explore video grids and their skeletons.
const kFeedGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: kFeedGridSpacing,
  mainAxisSpacing: kFeedGridSpacing,
  childAspectRatio: kFeedGridChildAspectRatio,
);
```

- `explore_screen.dart` and `home_screen.dart` use `kFeedGridDelegate` in every `SliverGrid`. Section padding keeps `EdgeInsets.fromLTRB(kFeedGridSpacing, first ? kFeedGridSpacing : 0, kFeedGridSpacing, 0)`.
- `estimateFeedGridOffset` ([feed_grid_reveal.dart](../../lib/widgets/feed_grid_reveal.dart)) drops its `horizontalPadding` / `spacing` / `childAspectRatio` parameters, which no caller overrides, and reads the constants instead. It gains `double headerOffset = 0`, which is added to the result. Home's call is unchanged.

### 2. Skeleton sliver: `lib/widgets/feed_grid_skeleton_sliver.dart` (new)

```dart
// lib/widgets/feed_grid_skeleton_sliver.dart
class FeedGridSkeletonSliver extends StatelessWidget {
  const FeedGridSkeletonSliver({
    super.key,
    required this.itemCount,
    this.padding = const EdgeInsets.fromLTRB(
      kFeedGridSpacing, kFeedGridSpacing, kFeedGridSpacing, 0),
  });
  // SliverPadding > SliverGrid(kFeedGridDelegate) of
  // ClipRRect(radius 12, BeatShimmerFill()), wrapped in
  // SliverSemantics / Semantics(label: 'Loading videos').
}
```

- **Explore:** first load (`ExploreInitial`, `ExploreLoading`) shows `FeedGridSkeletonSliver(itemCount: 8)` under the header. Load-more shows `itemCount: 2` with `EdgeInsets.fromLTRB(6, 12, 6, 0)`.
- **Home:** the three `ShimmerLoading(cardCount: 8)` returns ([home_screen.dart:162,166,195](../../lib/screens/home/home_screen.dart#L162)) become `CustomScrollView(physics: NeverScrollableScrollPhysics(), slivers: [FeedGridSkeletonSliver(itemCount: 8)])`, and `_buildLoadingSliver` becomes `FeedGridSkeletonSliver(itemCount: 2, …)`.
- **Delete:** `lib/widgets/shimmer_loading.dart` (`ShimmerLoadingIndicator` is unused) and `lib/screens/explore/video_feed/widgets/search_loading_card.dart`.

### 3. `BeatShimmerFill` reduced motion: `lib/widgets/beat_shimmer.dart`

When `MediaQuery.disableAnimationsOf(context)` is true, return the static `ColoredBox(color: colorScheme.surfaceContainerHighest)` with no `Shimmer` animation. Colours stay as they are; they already follow the seeded light and dark schemes.

### 4. Thumbnails: `lib/widgets/video_feed_card.dart` (shared with Home)

```dart
// lib/widgets/video_feed_card.dart
Image.network(
  thumbnailUrl,
  fit: BoxFit.cover,
  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded) return child; // cache hit: no fade, no shimmer
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: frame == null
          ? const BeatShimmerFill(key: ValueKey('thumb-placeholder'))
          : KeyedSubtree(key: const ValueKey('thumb-image'), child: child),
    );
  },
  errorBuilder: (context, error, stackTrace) => ColoredBox(
    color: colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(Icons.video_library_outlined,
        color: colorScheme.onSurfaceVariant, size: 36)),
  ),
)
```

- Remove `loadingBuilder`. `AnimatedSwitcher` drops the shimmer after the fade, so no animation keeps running under a loaded image.
- **No `cacheWidth`.** This is deferred; see the umbrella plan.

### 5. Single scroll view with floating header: `lib/screens/explore/explore_screen.dart`

```text
Scaffold > SafeArea > BlocListener(scroll-to-top) > RefreshIndicator(edgeOffset: _headerExtent)
  └─ CustomScrollView(controller, AlwaysScrollableScrollPhysics,
                      keyboardDismissBehavior: onDrag)
       ├─ SliverFloatingHeader(child: ColoredBox(scaffoldBackgroundColor, child: SearchHeader(key: _headerKey)))
       └─ state slivers:
            Initial / Loading  → FeedGridSkeletonSliver(itemCount: 8)
            Error              → SliverFillRemaining(hasScrollBody: false, ExploreErrorState)
            Loaded, empty      → SliverFillRemaining(hasScrollBody: false, ExploreEmptyState | NoResultsState)
            Loaded             → _ResultsCountSliver (search mode only)
                                 video sections + ad slivers
                                 FeedGridSkeletonSliver(itemCount: 2) if isLoadingMore
                                 _LoadMoreRetrySliver if loadMoreFailed
                                 SliverToBoxAdapter(SizedBox(height: 24))
```

- **Remove** `_buildRefreshableBody` and the `Column`/`Expanded` layout. `ExploreInitial` now shows the skeleton; it only lasts for the first frame because the screen adds a search immediately.
- **Header background:** the floating header paints `theme.scaffoldBackgroundColor`, matching the Scaffold behind it, so cards don't show through behind it.
- **Header extent:** `_headerKey` sits on the header content. A post-frame callback in `build` reads `_headerKey.currentContext?.size?.height` and calls `setState` only when the value changes. The header grows by about 56 px when the expanded search bar opens. Until the first measurement, use a fallback constant (`_fallbackHeaderExtent = 58`). The measured value feeds both `RefreshIndicator.edgeOffset` and the reveal estimate.
- **Scroll to top on a new search:** a `BlocListener` with `listenWhen: (_, s) => s is ExploreLoading` calls `_scrollController.jumpTo(0)` when `hasClients && pixels > 0`. The persistent scroll view would otherwise keep a deep offset while the content shrinks to the skeleton. Refresh is already at the top, so the `pixels > 0` guard makes it a no-op there.
- **Results line:** `_ResultsCountSliver` is a `SliverToBoxAdapter` with the existing copy, styled with `colorScheme.onSurfaceVariant` in place of `Colors.grey[600]`. The retry text's `Colors.grey[600]` gets the same change.
- **Focus on navigation:** call `FocusManager.instance.primaryFocus?.unfocus()` before `pushNamed` in the card's `onTap` and `onUsernameTap`. When the route pops, focus would otherwise come back to the field, reopening the keyboard and pulling the header into view while `revealFeedGridItem` runs.
- **Reveal:** `_revealVideo` passes `headerOffset: _headerExtent + (isRandomFeed ? 0 : _resultsLineExtent)` (`_resultsLineExtent = 40`). `Scrollable.ensureVisible` in `revealFeedGridItem` does the final alignment, so the estimate only needs to be close.
- **Private widgets:** the sliver builders become small private widgets in the same file (`_VideoSectionSliver`, `_LoadMoreRetrySliver`, `_ResultsCountSliver`). `_ExploreFeedSection.videos` becomes `List<SportVideo>`. This file is being rewritten anyway, so the brainstorm's widget cleanup happens here, and Part 2 only changes the state types.

### 6. Selected chip into view: `lib/screens/explore/video_feed/widgets/search_header.dart`

- Add a `_chipScrollController` on the horizontal `SingleChildScrollView`, and one `_selectedChipKey` that is assigned to whichever chip is selected.
- In `didUpdateWidget`, when `selectedFilterId` changes, a post-frame callback calls `_chipScrollController.position.ensureVisible(_selectedChipKey.currentContext!.findRenderObject()!, alignment: 0.5, duration: 200ms, curve: Curves.easeOut)`. Null-check the context first.
- **Use `ScrollPosition.ensureVisible`, not `Scrollable.ensureVisible`.** The latter walks every ancestor `Scrollable` and would also scroll the vertical grid.
- Dispose the controller.

## Technical Considerations

- **Architecture:** presentation only. No bloc, state, event or service change.
- **Performance:** each shimmer is removed once its image loads, so animations don't run behind loaded images. A synchronous cache hit (`wasSynchronouslyLoaded`) skips both shimmer and fade, so returning from the feed doesn't flash.
- **Accessibility:** skeletons carry a "Loading videos" semantics label. Shimmer is static when reduced motion is on.
- **Home impact:** thumbnail placeholder, fade and error tile, plus the skeleton widget. Home's reveal defaults are unchanged (`headerOffset: 0`).
- **Known PR 1 limitations (both fixed by Part 2):**
  - Refresh still emits `ExploreLoading`, so the grid swaps to skeletons under the refresh spinner.
  - Pull-to-refresh during a pending 500 ms debounce refreshes the previous query, and the debounced search then runs on its own. This is existing behaviour, and Part 2 deletes the widget-side debounce.

## Tests

- [ ] `test/widgets/feed_grid_reveal_test.dart`: update `estimateFeedGridOffset` calls. Add a unit test that `headerOffset: 100` adds exactly 100 to the result for index 0 and index 10.
- [ ] `test/widgets/video_feed_card_test.dart` (new):
  - while the image is pending, `find.byType(BeatShimmerFill)` finds one widget (use an `HttpOverrides` / test image provider that never completes);
  - an error shows the `video_library_outlined` icon on `surfaceContainerHighest`.
- [ ] `test/widgets/beat_shimmer_test.dart` (new): with `MediaQuery(disableAnimations: true)`, no `Shimmer` widget is in the tree.
- [ ] `test/widgets/feed_grid_skeleton_sliver_test.dart` (new): renders `itemCount` `BeatShimmerFill` cards, and exposes the "Loading videos" semantics label (`find.bySemanticsLabel`). Part 3 extends this file.
- [ ] `test/screens/explore/video_feed/widgets/search_header_test.dart` (new): pump `SearchHeader` inside a vertical `CustomScrollView` scrolled to 200 px, then select the last chip via `didUpdateWidget`:
  - the chip row's offset becomes greater than 0;
  - the vertical scroll position is still 200. This guards the `ScrollPosition.ensureVisible` choice.
- [ ] `test/screens/explore/explore_screen_test.dart`:
  - the existing refresh tests still pass (pull-to-refresh through the `SliverFloatingHeader`);
  - while the search is unresolved (`Completer`), `FeedGridSkeletonSliver` is shown and `CircularProgressIndicator` is not;
  - the error state is refreshable (fling down, verify the second call);
  - after dragging up, `SearchHeader` goes off-screen, and a small drag down brings it back (`tester.getTopLeft`);
  - while `isLoadingMore`, two extra skeleton cards appear (delay the second page with a `Completer`);
  - selecting a filter while scrolled down resets the offset to 0.
- [ ] `test/screens/home/home_screen_test.dart`: `ShimmerLoading` assertions become `FeedGridSkeletonSliver`.

## Implementation Phases

All three phases land in **one PR**; each phase is one commit.

### Phase 1: Format baseline, shared geometry, skeleton and thumbnails

- **Status:** Done
- **Scope:**
  - **Format-only commit first:** run `dart format` on `explore_screen.dart`, `search_header.dart`, `video_feed_card.dart`, `explore_empty_state.dart`, `explore_error_state.dart` and `home_screen.dart`, which are unformatted on `main`. This keeps later diffs readable.
  - Then add `feed_grid_geometry.dart` and `FeedGridSkeletonSliver`, switch Home to them, delete `shimmer_loading.dart` and `search_loading_card.dart`, and make the `BeatShimmerFill` reduced-motion and `VideoFeedCard` thumbnail changes.
  - `estimateFeedGridOffset` gains `headerOffset`.
- **Files touched:** `lib/widgets/feed_grid_geometry.dart`, `lib/widgets/feed_grid_skeleton_sliver.dart`, `lib/widgets/beat_shimmer.dart`, `lib/widgets/video_feed_card.dart`, `lib/widgets/feed_grid_reveal.dart`, `lib/widgets/shimmer_loading.dart` (deleted), `lib/screens/explore/video_feed/widgets/search_loading_card.dart` (deleted), `lib/screens/explore/explore_screen.dart` (delegate and skeleton swaps only), `lib/screens/home/home_screen.dart`, `test/widgets/*`, `test/screens/home/home_screen_test.dart`
- **Acceptance criteria:**
  - The skeleton, shimmer, card and reveal tests pass.
  - Home renders `FeedGridSkeletonSliver`.
  - No `ShimmerLoading` or `SearchLoadingCard` references remain.
- **Validation:** `flutter test test/widgets test/screens/home test/screens/explore`

### Phase 2: Floating header and single scroll view

- **Status:** Done
- **Scope:**
  - Rebuild `explore_screen.dart` as one `CustomScrollView` with `SliverFloatingHeader`, state slivers, `SliverFillRemaining` empty and error states, the results-count sliver, the measured `edgeOffset`, scroll-to-top on a new search, unfocus before navigation, and the reveal `headerOffset`.
  - Turn the sliver builders into private widgets.
- **Files touched:** `lib/screens/explore/explore_screen.dart`, `test/screens/explore/explore_screen_test.dart`
- **Acceptance criteria:**
  - The existing refresh tests pass through the floating header.
  - The new header hide/show, error-refresh, load-more skeleton and scroll-to-top tests pass.
- **Validation:** `flutter test test/screens/explore`

### Phase 3: Chip scroll-into-view

- **Status:** Done
- **Scope:** `SearchHeader` chip `ScrollController` plus `ScrollPosition.ensureVisible` for the selected chip.
- **Files touched:** `lib/screens/explore/video_feed/widgets/search_header.dart`, `test/screens/explore/video_feed/widgets/search_header_test.dart`
- **Acceptance criteria:** the chip row scrolls to the selected chip and the vertical position is unchanged.
- **Validation:** `flutter test test/screens/explore && flutter test`

## Success Criteria

```success-criteria
GOAL: Explore shows theme-aware shimmer skeletons and fading thumbnails under a floating search/chip header in a single scroll view, with grid geometry and the skeleton grid shared with Home, and no ExploreBloc changes.

SUCCESS CRITERIA:
- First load and load-more render FeedGridSkeletonSliver, not CircularProgressIndicator or SearchLoadingCard | verify: flutter test test/screens/explore/explore_screen_test.dart && ! grep -rq "SearchLoadingCard\|CircularProgressIndicator" lib/screens/explore/explore_screen.dart
- ShimmerLoading and SearchLoadingCard are deleted and nothing references them | verify: test ! -e lib/widgets/shimmer_loading.dart && test ! -e lib/screens/explore/video_feed/widgets/search_loading_card.dart && ! grep -rqE "ShimmerLoading|SearchLoadingCard" lib test
- Grid geometry is defined once; no literal 0.64 aspect ratio remains in the feed screens or reveal helper | verify: ! grep -qE "0\.64\b" lib/screens/explore/explore_screen.dart lib/screens/home/home_screen.dart lib/widgets/feed_grid_reveal.dart && grep -q "kFeedGridDelegate" lib/widgets/feed_grid_geometry.dart
- Loading thumbnails show BeatShimmerFill and the light-only/hard-coded colours are gone | verify: flutter test test/widgets/video_feed_card_test.dart && ! grep -qE "0xFFCDD3DD|0xFF323846" lib/widgets/video_feed_card.dart
- Shimmer is static when reduced motion is on, and skeleton cards are labelled for screen readers | verify: flutter test test/widgets/beat_shimmer_test.dart test/widgets/feed_grid_skeleton_sliver_test.dart
- Selecting a chip scrolls only the chip row, not the grid | verify: flutter test test/screens/explore/video_feed/widgets/search_header_test.dart
- estimateFeedGridOffset accepts headerOffset and Home's default behaviour is unchanged | verify: flutter test test/widgets/feed_grid_reveal_test.dart test/screens/home/home_screen_test.dart
- The explore body is one CustomScrollView with a SliverFloatingHeader and no _buildRefreshableBody/SingleChildScrollView path | verify: grep -q "SliverFloatingHeader" lib/screens/explore/explore_screen.dart && ! grep -qE "_buildRefreshableBody|SingleChildScrollView" lib/screens/explore/explore_screen.dart
- Results line uses theme colours | verify: ! grep -q "Colors.grey\[" lib/screens/explore/explore_screen.dart
- Touched code is analyzer-clean and formatted | verify: flutter analyze lib/screens/explore lib/widgets lib/screens/home/home_screen.dart test/widgets test/screens/explore test/screens/home && dart format --output=none --set-exit-if-changed $(git diff --name-only --diff-filter=d $(git merge-base main HEAD) -- '*.dart')
- Full suite stays green | verify: flutter test
- Visual check in both themes | verify: manual 1. Run the app in light mode, open Explore on a cold start: skeleton cards are pink-tinted and match card shape and spacing. 2. Scroll down: header hides; scroll up slightly: header returns. 3. Pull to refresh: the indicator appears below the header, not over it. 4. Thumbnails fade in, no grey box flash. 5. Switch to dark mode and repeat 1-4: skeletons are cyan-tinted. 6. Select a chip far right in the row: it scrolls into view and the grid jumps to top. 7. Open search, type, scroll the grid: keyboard dismisses and header floats away. 8. Enable OS reduce-motion: skeletons are static.
- Grid reveal still lands on the right card | verify: manual 1. On Explore browse mode, tap the 3rd card, swipe ~15 videos in the full-screen feed, go back: the grid shows the current video's card near the upper third, not hidden under the header. 2. Repeat in search mode (query + chip), confirming the results line doesn't offset the reveal. 3. With the search field focused before tapping a card, go back: keyboard stays closed. 4. Repeat step 1 on Home: behaviour unchanged.

NON-GOALS:
- Any ExploreBloc state, event or service change (Part 2)
- Spinner replacement outside Explore/Home grids (Part 3)
- cacheWidth / disk caching for thumbnails (deferred: conflicts with PooledVideoSurface poster reuse)
- Video card content (title, sport, avatar) and restyling empty/error states
- Pinning the header while search has focus

VERIFICATION COMMAND: flutter test && test ! -e lib/widgets/shimmer_loading.dart && test ! -e lib/screens/explore/video_feed/widgets/search_loading_card.dart && ! grep -rqE "ShimmerLoading|SearchLoadingCard" lib test && ! grep -q "CircularProgressIndicator" lib/screens/explore/explore_screen.dart && ! grep -qE "0\.64\b" lib/screens/explore/explore_screen.dart lib/screens/home/home_screen.dart lib/widgets/feed_grid_reveal.dart && grep -q "kFeedGridDelegate" lib/widgets/feed_grid_geometry.dart && ! grep -qE "0xFFCDD3DD|0xFF323846" lib/widgets/video_feed_card.dart && grep -q "SliverFloatingHeader" lib/screens/explore/explore_screen.dart && ! grep -qE "_buildRefreshableBody|SingleChildScrollView" lib/screens/explore/explore_screen.dart && ! grep -q "Colors.grey\[" lib/screens/explore/explore_screen.dart && flutter analyze lib/screens/explore lib/widgets lib/screens/home/home_screen.dart test/widgets test/screens/explore test/screens/home
```

## Success Metrics

- No spinner is visible on Explore's first load or load-more.
- No light-grey placeholder flashes in dark mode.
- More grid rows are visible while scrolling, because the header floats away.

## Dependencies & Risks

- **Dependencies:** none. This builds on `main` as it is today.
- **Risk: `RefreshIndicator` with `SliverFloatingHeader`.** Covered by the existing refresh widget tests and manual step 3. Fallback: drop `edgeOffset` and accept the indicator over the header.
- **Risk: the post-frame header measurement loops.** `setState` runs only when the height changes by more than 0.5 px.
- **Risk: Home regressions from the shared `VideoFeedCard`.** Covered by the Home tests and manual reveal step 4.

## References & Research

- Brainstorm: [2026-10-13-explore-screen-polish-brainstorm-doc.md](../brainstorm/2026-10-13-explore-screen-polish-brainstorm-doc.md)
- `SliverFloatingHeader`: `$FLUTTER/packages/flutter/lib/src/widgets/sliver_floating_header.dart` (Flutter 3.47.7)
- Poster reuse: [pooled_video_surface.dart:44](../../lib/widgets/pooled_video_surface.dart#L44)
- Theme seeds: [app_themes.dart:142](../../lib/constants/app_themes.dart#L142), [:233](../../lib/constants/app_themes.dart#L233)
- Reveal helper: [feed_grid_reveal.dart](../../lib/widgets/feed_grid_reveal.dart)
- Related PR: #1 (media_kit player pool, which introduced `revealFeedGridItem` and the pooled poster)
