# Architecture Review: refactor/upload-category-hubs-ui

Base: `main`. Scope: uncommitted changes listed in the task, plus the untracked files.

Stack detected: Flutter app (single package `beat_that`), `flutter_bloc` for state, `go_router` for navigation, `get_it` service locator (`locator<SupabaseService>()`), `flutter_lints`. The repo has no `CLAUDE.md`, no `.claude/skills`, and no companion-plugin skills, so this review applies VGV defaults plus the conventions already present in the repo.

Project layering, inferred from the directory layout:

- Data/services: `lib/services/*` (SupabaseService and others), `lib/models/*`
- Presentation: `lib/screens/<feature>/{bloc,*_screen.dart}`
- Shared UI: `lib/widgets/*`, `lib/constants/*`
- Navigation: `lib/routes/app_router.dart`

## Layer Separation

- Violations found: 0 new.
  - The blocs still read `SupabaseService` directly through `locator`, with no repository. That pattern predates this branch and the change leaves it as it was.
  - `GamingHubBloc` and `UploadCategoryBloc` now import `constants/app_strings.dart`. `SportsHubBloc` on `main` already does this, so the change follows the repo's convention rather than breaking it.
- Shared-widget coupling (new):
  - `lib/widgets/hub_page.dart:3,32` imports `go_router` and calls `context.pop()` from inside a shared widget. It is the only file in `lib/widgets/` that depends on the router. `ErrorScreen`, its closest sibling, takes navigation as callbacks (`secondaryButtonCallback`). Hard-wiring `pop` makes `HubPage` hard to test without a `GoRouter` above it, and it throws if the page is ever the root of a stack.
  - `lib/widgets/category_hub_grid.dart:1` depends on `models/category.dart`. The deleted `sport_grid_item.dart` had the same dependency, so this is acceptable.
- Clean files: `app_strings.dart`, `hub_tile.dart`, `gaming_hub_event.dart`, `sports_hub_state.dart`, `upload_category_state.dart`.

## State Management Assessment

- **GamingHubBloc**: correct, with one observability concern.
  - Removing the no-op `on<GamingHubEvent>((event, emit) {})` is safe. That handler did nothing, and `LoadGamingHubEvent` still has its own handler. Events are unchanged.
  - `gaming_hub_bloc.dart:24`: `catch (_)` throws away the exception and stack trace. Before this change the error at least reached the screen through `e.toString()`. Now no log, observer, or crash reporter ever sees it. The repo has no `BlocObserver`, so `addError` would also need an observer or a logger behind it.
- **UploadCategoryBloc**: correct, with the same concern.
  - `upload_category_bloc.dart:33`: `catch (_)` silently drops the error.
  - The empty-list guard at `:27` checks raw image URLs. The screen now filters out URLs it cannot map to a category (`upload_category_screen.dart:99-112`). If every URL were unknown, the bloc would emit `Loaded` and the screen would show a header over an empty list instead of the `noUploadCategories` error. Today `SupabaseService.getCategoryImages()` returns a hard-coded `['gaming.png', 'sports.png']`, so nothing breaks yet. Still, mapping URLs to categories and routes is business logic. It now lives in the widget, and that weakens the bloc's guarantee.
- **SportsHubState / UploadCategoryState** (`sealed`): correct. Every subclass sits in the same library as its sealed base, so sealing compiles. The unused `SubcategoriesLoaded` state was removed, and nothing referenced it (verified with grep).
  - `sports_hub_screen.dart:145`, `gaming_hub_screen.dart:57`, and `upload_category_screen.dart:41` each end their switch with a `_ =>` wildcard. That arm absorbs `Initial`, `Loading`, and the unreachable `Error`, which cancels the main benefit of sealing: the compiler can no longer flag a new state that lacks a UI branch.
- **Screens / UI logic**: no business logic leaked into callbacks beyond the upload-category mapping noted above. Haptics and `pushNamed` stay in the view, which is appropriate. Route names (`sport-details`, `sports-hub`, `gaming-hub`) and extras (`SportDetailsExtra(sport: ...)`) are unchanged.
- **Double app bar fix**: confirmed. `HubGridLoadingView`, which carried its own `Scaffold` and `AppBar`, was nested inside the screen's `Scaffold`. Now one `HubPage` scaffold wraps all non-error states and only swaps the sliver.
- **Provider lifecycle**: unchanged. The `BlocProvider(create: ...)` calls remain in the screens and the router.

## Dependency Direction

- Direction violations: 0.
- Circular dependencies: none. `hub_page.dart` imports nothing from `lib/`. `hub_tile.dart` imports `constants/app_colors.dart` and `widgets/beat_shimmer.dart`. `category_hub_grid.dart` imports `models/category.dart` and `widgets/hub_tile.dart`. Screens import the widgets; no widget imports a screen.
- Clean: screens -> widgets -> constants/models; blocs -> services/models/constants.

## Package / Widget Structure

Single-package app; no new packages.

- **`lib/widgets/hub_page.dart`** (new, public): it is a cohesive shell and replaces three copies of the same app bar, header, and scroll layout. No test covers it. The header padding math (`MediaQuery.paddingOf(context).top + kToolbarHeight`), the back-button behavior, and the title and subtitle rendering are all untested.
- **`lib/widgets/hub_tile.dart`** (new): it is well factored. Private `_TileFrame` and `_TileContent` are shared between `HubTile` and `HubTileSkeleton`, which keeps the skeleton aligned with the real tile. `test/widgets/hub_tile_test.dart` tests it. `HubTileSkeleton` itself has no test.
- **`lib/widgets/category_hub_grid.dart`** (new): it has a focused responsibility. The `wrapTile` hook is a reasonable seam for the onboarding target and keeps onboarding knowledge out of the shared widget. Its tests live in `test/widgets/hub_tile_test.dart`, not in a matching `category_hub_grid_test.dart`, so the test tree no longer mirrors `lib/`. `CategoryHubGridSkeleton` has no test.
- **Deleted `hub_grid_loading_view.dart` and `sport_grid_item.dart`**: grep finds no remaining references in `lib/` or `test/`.
- **`AppStrings`**: the new copy is grouped under clear section comments. The onboarding target copy in the rewritten hunk at `sports_hub_screen.dart:136-140` remains hard-coded. It also differs slightly from the copy at `:61-64` ("open its techniques. Next, choose" versus "see its techniques. Then choose"). This partly undercuts the PR's stated goal of moving copy to `AppStrings`.
- **Router**: only two hunks changed. One fixes a doc comment. The other changes the `gaming-hub` and `sports-hub` transitions from a vertical slide (`Offset(0, 1)`) to a horizontal slide (`Offset(1, 0)`). Paths, names, and extras are unchanged. The horizontal push suits the new back-chevron chrome, but it is a visible behavior change that the stated scope omits.
- **Tests for changed blocs**: neither `GamingHubBloc` nor `UploadCategoryBloc` has a test, and both changed their error output. The repo has bloc tests elsewhere (`test/bloc/*`), so the omission breaks a pattern the project already follows.

## Findings

### Critical

1. **missing-widget-test**: Add widget tests for `HubPage`. `lib/widgets/hub_page.dart`. A new public shared widget, used by three screens, has no tests. It owns the safe-area and header offset math and the back navigation. Fix: add `test/widgets/hub_page_test.dart` covering title and subtitle, the sliver body, and back-button invocation.

### Important

2. **shared-widget-router-coupling**: Inject back navigation into `HubPage` instead of calling `context.pop()`. `lib/widgets/hub_page.dart:3,32`. It is the only `lib/widgets` file that imports `go_router`. Tests need a `GoRouter`, and `pop` throws when nothing is below the page. Fix: accept an `onBack` callback (defaulting to `Navigator.maybePop`), as `ErrorScreen` does.
3. **swallowed-exception**: Log or report errors before emitting generic copy. `lib/screens/gaming_hub/bloc/gaming_hub_bloc.dart:24` and `lib/screens/upload_category/bloc/upload_category_bloc.dart:33`. `catch (_)` discards the exception and stack trace, so failures are now invisible in logs and crash reporting. Fix: use `catch (e, st)` and call `addError(e, st)`, backed by a `BlocObserver` or logger, before emitting the generic error.
4. **missing-bloc-test**: Add bloc tests for the changed error paths. `GamingHubBloc` and `UploadCategoryBloc` now emit `AppStrings.somethingWentWrongPleaseTryAgain`, and nothing locks that in. Fix: add `blocTest`s that stub `SupabaseService` to throw and assert the generic error state, plus the empty-URL case for upload.
5. **business-logic-in-ui**: Resolve upload categories in the bloc, not the widget. `lib/screens/upload_category/upload_category_screen.dart:80-112`. The widget drops unknown URLs after the bloc's empty check, so a `Loaded` state can render an empty list without the "no categories" error. Fix: map URLs to categories in `UploadCategoryBloc`, emit a typed list, and apply the empty guard to that list.

### Suggestion

6. **sealed-exhaustiveness**: Replace `_ =>` wildcards with explicit state cases. `lib/screens/sports_hub/sports_hub_screen.dart:145`, `lib/screens/upload_category/upload_category_screen.dart:41`, `lib/screens/gaming_hub/gaming_hub_screen.dart:57`. The wildcard defeats the compile-time check that sealing was meant to add. Fix: list `Initial() || Loading()` explicitly and handle `Error` inside the switch, or assert it unreachable.
7. **hardcoded-copy**: Move the sports onboarding target copy to `AppStrings`. `lib/screens/sports_hub/sports_hub_screen.dart:136-140`. The rewritten hunk keeps hard-coded copy that already differs from the step copy at `:61-64`. Fix: add a single pair of `AppStrings` constants and use them in both places.
8. **test-file-mirroring**: Move the `CategoryHubGrid` tests into `test/widgets/category_hub_grid_test.dart` and add skeleton coverage. `test/widgets/hub_tile_test.dart:56`. The test tree no longer mirrors `lib/`, and neither skeleton widget is tested. Fix: split the file, then add smoke tests for `HubTileSkeleton` and `CategoryHubGridSkeleton`.
9. **unstated-behavior-change**: Call out the hub transition change. `lib/routes/app_router.dart:944,974`. The change from a vertical to a horizontal slide is visible to users but absent from the "purely UI/refactor" scope. Fix: mention it in the PR description, or revert it if it was unintended.

## Verdict

The architecture is sound: no layer or dependency-direction violations, and a net reduction of about 900 lines through cohesive shared widgets. Before merging, fix the missing `HubPage` test (Critical). The four Important items should also be fixed: router coupling in the shared widget, swallowed exceptions, missing bloc tests, and the category mapping in the UI.
