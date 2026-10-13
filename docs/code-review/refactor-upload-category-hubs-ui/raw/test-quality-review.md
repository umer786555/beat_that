## Test Quality Review

### Coverage Summary
- Test run: Pass (321 tests, full suite with coverage; `test/widgets/hub_tile_test.dart` 3/3)
- Project conventions: bloc_test + mocktail; `MockSupabaseService extends Mock implements SupabaseService`, registered with `locator.registerSingleton` in `setUp` and `await locator.reset()` in `tearDown` (see `test/bloc/explore_bloc_test.dart`). Screen tests exist under `test/screens/*`.
- Line coverage of changed/new files (from lcov):
  - `lib/widgets/hub_tile.dart` 65/83 (78%)
  - `lib/widgets/category_hub_grid.dart` 12/17 (71%; `CategoryHubGridSkeleton` uncovered)
  - `lib/widgets/hub_page.dart` 0/40 (0%)
  - `lib/screens/gaming_hub/bloc/gaming_hub_bloc.dart` 0/16
  - `lib/screens/upload_category/bloc/upload_category_bloc.dart` 0/12
  - `lib/screens/upload_category/upload_category_screen.dart` 4/40
  - `lib/screens/gaming_hub/gaming_hub_screen.dart` 2/21
  - `lib/screens/sports_hub/sports_hub_screen.dart` 1/47
  - `lib/screens/sports_hub/sports_hub_bloc/sports_hub_bloc.dart` 0/26 (unchanged, not in scope)
- Files with tests: 2 of 3 new widgets (`hub_tile.dart`, `category_hub_grid.dart` share one test file). `hub_page.dart` has none.
- Missing test files:
  - `lib/widgets/hub_page.dart` — No corresponding test
  - `lib/screens/gaming_hub/bloc/gaming_hub_bloc.dart` — No test (behavior changed: generic error copy, handler removed)
  - `lib/screens/upload_category/bloc/upload_category_bloc.dart` — No test (behavior changed: error copy via AppStrings)
  - `lib/screens/upload_category/upload_category_screen.dart`, `gaming_hub_screen.dart`, `sports_hub_screen.dart` — No widget tests for rewritten screens

### State Management Test Quality
- gaming_hub_bloc (no test): the catch branch now emits `GamingHubError(AppStrings.somethingWentWrongPleaseTryAgain)` instead of `e.toString()`. This is a deliberate behavior change (stops leaking raw exceptions) and nothing asserts it. Success ordering (alphabetical, "Other Games" last) is also untested.
- upload_category_bloc (no test): empty list -> `noUploadCategories`; thrown exception -> generic copy (no `$e`); retry re-runs fetch. All untested.
- Removed `on<GamingHubEvent>((event, emit) {})` no-op: safe, since the sealed event has a single subtype handled by `LoadGamingHubEvent`.

### UI Component Test Quality
- hub_tile_test.dart: Issues found
  - HubTile: success path (title, subtitle, tap) is covered. Not covered: non-null `imageUrl` (loading and error builder fall back to placeholder), the title `maxLines` switch (2 without subtitle, 1 with), `HubTileSkeleton`, and the pressed-scale state.
  - "places the ink well above the image" asserts internal Stack child order (`stack.children.last as Positioned`). This tests implementation, not behavior; it breaks on harmless refactors. Prefer asserting that a tap on the tile's center invokes `onTap` and that an `InkWell` is a descendant.
  - CategoryHubGrid: tap passes the category and `wrapTile` applies to index 0 only. Missing: empty list, `CategoryHubGridSkeleton` item count, wrapTile returning the tile unchanged for other indices.
- hub_page.dart (no test): back button calling `context.pop()`, header title/subtitle rendering, and the sliver slot are all untested.
- Screens (no tests): error state shows `ErrorScreen` with Retry dispatching the right event (`LoadGamingHubEvent`, `RetrySportsEvent(locale)`, `RetryUploadCategoryImagesEvent`) and "Go Back"; loading shows skeleton; loaded shows tiles and pushes the same route names and `SportDetailsExtra` extras. The task states routes, extras and events must not change, and nothing guards that.

### Anti-Patterns Found
- **test/widgets/hub_tile_test.dart:36-48** — Implementation mirroring
  - Issue: Walks `Stack.children.last as Positioned` to assert widget ordering.
  - Fix: Assert observable behavior (tap triggers `onTap`; `InkWell` exists under `HubTile`).
- **lib/screens/upload_category/upload_category_screen.dart:~95-115 (behavior change, untested)** — Missing edge-case test
  - Issue: On `main`, an image with an unrecognized file name still rendered a card (title derived from the name, tap was a no-op). Now `_Category.fromImageUrl` returns null and the card is dropped. If no image matches, `_CardColumn` renders an empty list with no empty-state or error. This is a visible change in a refactor, and no test pins either behavior.
  - Fix: Decide the intended behavior and add a screen test (matching `sports.png`/`gaming.png`, unknown file, all-unknown).
- **lib/routes/app_router.dart:944,974** — Unverified behavior change
  - Issue: The gaming-hub transition changed from a bottom slide `Offset(0,1)` to a right slide `Offset(1,0)`, which is not purely refactor and has no test.
  - Fix: Confirm this is intended, or revert.

### Recommendations
1. Add `hub_page_test.dart` (back button pops, title/subtitle shown, sliver slot rendered).
2. Add bloc tests with bloc_test + mocktail for `GamingHubBloc` and `UploadCategoryBloc` following the `explore_bloc_test.dart` setup, asserting `[Loading, Error(AppStrings.somethingWentWrongPleaseTryAgain)]`, empty-list error, and sorted success.
3. Add screen tests (mock bloc or mock `SupabaseService` via `locator`) for the three rewritten screens covering loading/loaded/error, retry events, and route pushes with unchanged extras.
4. Replace the Stack-order assertion; extend HubTile tests to image and skeleton cases.

### Verdict
Fix issues before merging: new shared `HubPage` is untested, and the bloc and screen behavior changes (error copy, dropped unknown-category cards) have no test coverage.
