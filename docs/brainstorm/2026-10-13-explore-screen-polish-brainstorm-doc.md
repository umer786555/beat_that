---
date: 2026-10-13
topic: explore-screen-polish
---

# Explore Screen: Visual Polish and ExploreBloc Refactor

## What We're Building

Two pieces of work, done in this order:

1. **Visual pass on the Explore grid.**
   - Replace the bare first-load spinner and the flat grey load-more boxes with shimmer skeletons that match the grid's card geometry.
   - Make thumbnail loading look right in both themes.
   - Turn the search pill and sport chips into a floating header that hides on scroll down and comes back on scroll up.
2. **Refactor `ExploreBloc` onto flutter_bloc best practices.**
   - One immutable state with a status enum.
   - A typed, constructor-injected `ExploreRepository`.
   - `bloc_concurrency` event transformers in place of the hand-rolled debounce timer and the generation counter.

The work ships as **three PRs**:

- **PR 1, the visual pass.** Built on the current `ExploreBloc`, with no state or event changes. It covers Explore plus the shared `VideoFeedCard` and skeleton grid, so Home's thumbnails change too. It is independently mergeable and quick to review.
- **PR 2, the repository and bloc refactor.** It includes the `explore_bloc_test.dart` rewrite. Shipping it after PR 1 means the refactor's widget-test updates target the final scroll-view structure only once.
- **PR 3, the app-wide shimmer sweep.** It replaces the remaining content-loading spinners outside Explore with `BeatShimmerFill`. It is independent of PR 2 and can land any time after PR 1.

The full-screen feed (`ExploreVideoFeedCubit`, `ExploreFeedProgress`, player pool) is **not** refactored here. Its contract with the grid stays the same: `ExploreVideoFeedExtra` in, `ExploreFeedProgress` back through `ExploreFeedProgressStore`.

## Why This Approach

**Visual scope.** We chose loading and thumbnails plus header and scroll behaviour. Video card content (title, sport, real avatar) and restyling the empty and error states are deferred.

**Header.** We picked a floating header built with `SliverFloatingHeader`, which is available in Flutter 3.47. It sizes to its child, so it follows the search bar as it expands and collapses. `SliverAppBar` needs a fixed `toolbarHeight`.
- Rejected: keeping the chips pinned, which costs permanent vertical space.
- Rejected: leaving the header fixed.
- A floating header pushes the whole body into one `CustomScrollView`. That also removes the separate `_buildRefreshableBody` / `SingleChildScrollView` path used today for the empty and error states.

**State shape.** We considered three options:
1. A single state with a status enum. **Chosen.**
2. The current sealed family plus a separate filters cubit.
3. A plain Cubit.

The current sealed states don't hold disjoint data. `filterCatalog`, `selectedFilterId` and `query` survive every transition, which is why `_withFilterCatalog` (`explore_bloc.dart:336`) rebuilds all four subclasses. A single state removes that, and it matches the style of the sibling `ExploreVideoFeedCubit` and `HomeVideoFeedState`. A Cubit was rejected because it gives up event transformers, the main tool for removing the manual debounce and stale-response code.

**Refactor depth.** We chose bloc plus a typed repository, but not the feed cubit.
- The repository fixes a real bug: `SupabaseService.searchVideosByTitle` catches every error and returns an empty result, so a failed search shows "No matching videos" and never reaches the error state.
- Sharing the repository and cursor with `ExploreVideoFeedCubit` would remove the duplicated pagination logic. It was deferred because it touches the player-pool feed screen and its tests.

## Key Decisions

### Visual

- **Shimmer skeletons:**
  - The first load shows a skeleton grid inside the scroll view, under the header, in place of `CircularProgressIndicator`.
  - Load-more appends skeleton cards in place of `SearchLoadingCard`.
  - `BeatShimmerFill` (`lib/widgets/beat_shimmer.dart`) is the single shimmer primitive for the whole app. It stays theme-driven: pink-tinted in light mode (seeded from `electricMagenta`) and cyan-tinted in dark mode (seeded from `cyan`). This matches how the chips and search bar already switch accent per theme.
  - The existing `ShimmerLoading` is a shrink-wrapped `GridView` with a different geometry (8 px spacing, 9/14 ratio), so it can't be used as a sliver. Add one sliver skeleton grid that takes its geometry as parameters. Explore uses it now. Home can switch to it as well, so there's one skeleton grid instead of two.
- **Shared grid geometry:**
  - Pull `crossAxisCount`, spacing, padding and `childAspectRatio` into one place.
  - The grid sections, skeleton slivers and `estimateFeedGridOffset` all read from it.
  - Today the values are repeated across `explore_screen.dart:341`, `:428` and the defaults in `feed_grid_reveal.dart:42`.
- **Thumbnails:**
  - Use a theme-aware shimmer placeholder in place of the light-only `0xFFCDD3DD` box.
  - Fade in the image when its first frame arrives (`frameBuilder`).
  - Decode at card size (`cacheWidth`) so full-size thumbnails aren't held in memory.
  - `VideoFeedCard` is shared with home, so home gets these improvements too.
- **Floating header:**
  - The search pill, expanded search bar and chips scroll away when you scroll down and snap back on the first upward scroll.
  - `RefreshIndicator` wraps the single scroll view. Its `edgeOffset` must account for the header.
- **Small header fixes:**
  - Scroll the selected chip into view.
  - Set `keyboardDismissBehavior: onDrag` on the scroll view.
  - Restyle the results-count line with theme colours in place of `Colors.grey[600]`. It becomes a sliver that scrolls with the grid.
- **Grid reveal:** returning from the full-screen feed must still scroll to the right card. `estimateFeedGridOffset` adds the header and results-line height to its jump target. `Scrollable.ensureVisible` in `revealFeedGridItem` then does the final alignment once the card is built. Pass the header offset in as a new optional parameter rather than changing the defaults, so Home's reveal behaviour is unchanged.

### App-wide shimmer sweep (PR 3)

- **Rule:** use `BeatShimmerFill` when **content with a known shape** is loading, such as thumbnails, grids, list rows or ad slots. Keep `CircularProgressIndicator` for **actions in progress** and video buffering.
- **Swap to shimmer:**
  - The image `loadingBuilder` spinner in `category_details_screen.dart:409`.
  - The load-more spinner in `creator_profile_screen.dart:235`. Use two shimmer cards, matching Home.
  - The ad-slot loading spinner in `feed_native_ad_card.dart:245`.
  - The full-screen spinners in `profile_connections_screen.dart:142` and `blocked_users_screen.dart:184`. These need one shared shimmer user-row skeleton.
- **Keep as spinners:**
  - Button busy states: follow, unblock, the settings toggles, auth buttons, the rating and report sheets.
  - The approval-pending badge and the deleting overlay in `profile_video_grid_item.dart`.
  - Video buffering in `pooled_video_surface.dart` and the feed pages.
  - The upload progress bar in `title_input_bottom_sheet.dart`.

### Bloc refactor

- **`ExploreState`:**
  - A single `Equatable` class with:
    - `status` (`initial`, `loading`, `success`, `failure`)
    - `query`
    - `selectedFilterId`
    - `filterCatalog`
    - `videos`
    - `cursor`
    - `hasMore`
    - `totalCount` (nullable: search mode only, since in random mode it's just `videos.length`)
    - `loadMoreStatus` (`idle`, `loading`, `failure`)
  - This removes `_withFilterCatalog`, the sentinel `copyWith`, and the `selectedFilterId ?? ''` props quirk that treats null and `''` as equal.
- **`ExploreCursor`:**
  - A sealed class with two variants, `SearchCursor(offset)` and `RandomCursor(seed, afterId, hasWrapped)`.
  - It replaces the five loose fields `nextOffset`, `isRandomFeed`, `randomSeed`, `randomAfterId` and `randomHasWrapped`.
  - `isRandomFeed` becomes `cursor is RandomCursor`.
  - The grid still flattens the cursor back into `ExploreVideoFeedExtra` so the feed cubit stays untouched.
- **`ExploreRepository`:**
  - Constructor-injected into the bloc. `ExploreScreen` reads it from `locator` and passes it in.
  - Returns a typed `ExplorePage { videos, hasMore, cursor, totalCount? }` and throws on failure.
  - Owns the stale-cursor (`errorCode == '22023'`) reset now done in `_loadRandomExplorePage`.
  - Owns browse-seed generation, behind an injectable seed source so tests are deterministic.
- **Error handling:**
  - Failures set `status: failure`, with no raw `'Failed to search videos: $e'` string.
  - The UI maps the failure to friendly copy and keeps the existing `ExploreErrorState` widget unchanged.
  - Search errors stop being reported as empty results.
- **Search cancellation:**
  - Query change, filter select and refresh/retry are subtypes of one sealed `ExploreSearchRequested`. A single `on<ExploreSearchRequested>(…, transformer: restartable())` handles them, so a new search always cancels the previous one.
  - **Debounce inside the handler.** For a non-empty query change, `await Future.delayed(500ms); if (emit.isDone) return;` runs before the repository call. Filter select, refresh and clear skip the delay, so they stay immediate as they are today.
  - Query changes whose normalized query and filter match the current state are ignored. This replaces the widget's `_submittedQuery`. Refresh always runs.
  - Together these replace the widget's `Timer`, `_submittedQuery` and the bloc's `_searchGeneration`.
- **Load-more:**
  - Load-more has its own handler with `droppable()`.
  - After the fetch, `if (state.cursor != requestCursor) return;` drops a page that belongs to a search that has since been replaced. Every new search resets the cursor, so this check is enough.
  - The `minQueryLength` / `effectiveQuery` rule moves fully into the bloc; the widget stops calling bloc statics.
- **Event merging:** handlers stop calling `add()` on the bloc itself. Refresh and retry are both the refresh subtype of `ExploreSearchRequested`.
- **New dependency:** `bloc_concurrency`. `stream_transform` isn't needed because the debounce lives inside the handler.
- **Widget cleanup:**
  - The `_buildX` helper methods in `explore_screen.dart` become small private widgets.
  - The typed `List<SportVideo>` replaces `List<dynamic>` in `_ExploreFeedSection`.
  - `ExploreInitial`'s "Search Videos" empty state goes away, because the screen starts loading immediately.

### Testing

- Rewrite `test/bloc/explore_bloc_test.dart` against a mocked `ExploreRepository` passed through the constructor, with no `locator` registration.
- Cover these paths:
  - debounce
  - restart on a new query
  - dropped duplicate load-more
  - stale-cursor reset
  - search failure reaching `failure`
  - merge-progress
- Add repository unit tests for map-to-`ExplorePage` parsing and error propagation.
- Update `test/screens/explore/explore_screen_test.dart` for the single scroll view and floating header.

## Open Questions

- **Header and pull-to-refresh.** Verify that `SliverFloatingHeader` works with `RefreshIndicator`, and set `edgeOffset` so the indicator appears below the header.
- **Expanded search bar.** Should the header stay visible while the search field has focus, or is dismissing the keyboard on drag enough?
- **Search errors and the feed cubit.** `ExploreVideoFeedCubit` also calls `SupabaseService.searchVideosByTitle`, so making that method throw would change the feed's behaviour too. Should the repository query Supabase itself and leave the service method as it is? This option is recommended.
- **Repository location.** Should `ExploreRepository` sit in `lib/services/`, next to `HomeFeedService`, or start a new `lib/repositories/` folder? No repository layer exists yet.
- **Disk caching for thumbnails.** Do we want `cached_network_image`, or is `Image.network` with `cacheWidth` enough for now? This is deferred unless profiling shows re-download cost.
- **Shared pagination (follow-up).** Should `ExploreVideoFeedCubit` and `ExploreFeedProgress` move onto `ExploreRepository` and `ExploreCursor` in a follow-up PR, to remove the duplicated pagination?
