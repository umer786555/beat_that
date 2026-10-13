---
date: 2026-10-13
topic: home-screen-refactor
---

# Home Screen Refactor

## What We're Building

A maintainability refactor of the home grid feed: `lib/screens/home/home_screen.dart` (495 lines) and `lib/screens/home/bloc/` (`HomeBloc`, states, events). The user experience stays the same. The goal is to bring home in line with the patterns already set by the explore (`8aba9a9`) and profile (`ffc0af1`) refactors, and to remove the over-engineering and duplicated state that make the screen hard to change.

The changes are:
- Split the screen into a stateless `HomeScreen`, which provides the bloc, and a private stateful `_HomeView`.
- Replace the six `_buildX()` helper methods with private widget classes.
- Merge the near-identical error and empty states into one widget under `lib/screens/home/widgets/`.
- Move hard-coded copy into `AppStrings`.
- Simplify `HomeBloc` so the widget no longer keeps its own copy of feed state.

Two low-risk latent bugs are fixed alongside, each in its own commit.

## Why This Approach

We considered three approaches:

- **A. Match the explore/profile pattern (chosen).** This is consistent with the rest of the recently refactored app. It keeps sealed `Equatable` states and removes the widget-side copy of feed state at its source.
- **B. UI-only cleanup.** This was lower risk, but it left the bloc's dead paths and the widget's `_lastLoadedVideos`, `_lastCursor` and `_lastHasMoreContent` fields untouched. Those are the main source of complexity.
- **C. A single `HomeState` with a status enum and `copyWith`.** This is the textbook shape for paginated lists. It was rejected because it breaks with the sealed-state pattern used elsewhere and forces a rewrite of the 563-line bloc test. Approach A solves the same problem with less churn.

## Key Decisions

### Scope

- **In scope:** `home_screen.dart`, `home/bloc/*`, the home widget tests and the bloc tests.
- **Out of scope:** the `home/video_feed/` subfeature (cubit, screen, page) and code shared with explore. Sharing ad-slot chunking, the error and empty widgets, and `formatViewCount` across features is deliberately deferred.

### Bloc changes

- **Constructor injection for `HomeBloc`.** Today it resolves its services with `locator<>()` inside the class. Injecting them through the constructor matches the profile bloc and removes the need for tests to register singletons.
- **Drop the `UserProfileLoaded` state.** No UI reads it, and the screen already treats it the same as `HomeInitial`.
- **Keep the profile cache writes.** `clearUserProfile` and `saveUserProfile` stay in `HomeBloc._onInitial`. They look unrelated to the feed, but `ProfileBloc` reads the cached profile through `fetchUserProfile` (profile_bloc.dart:77), and `HomeBloc` is what fills that cache. Moving them is out of scope.
- **Keep `HomeFeedService`.** It is a thin pass-through, but the video_feed cubit (out of scope) also uses it. Inject it, but do not delete it or change its return type here.
- **Replace event chaining with a private method.** `RefreshFeedEvent` and `LoadMoreFeedEvent` currently re-dispatch `FetchFeedEvent`. They will call a private `_fetchFeed(...)` method instead, and the pagination in-flight flag will be set and cleared in one place.
- **Remove dead code from the bloc:**
  - the `try/catch` → `FeedError` branches that can never run;
  - the unused `limit = 50` default;
  - `print()` calls;
  - the `offset ?? 0` in `FeedError.props`.

### Pagination state

- **`FeedLoaded` gets an `isLoadingMore` flag.** Pagination stops emitting `FeedLoading`. This lets us delete `_lastLoadedVideos`, `_lastCursor` and `_lastHasMoreContent` from the widget, which only exist because `FeedLoading` drops the video list. `FeedLoading` remains only for the first load and refresh.

### UI changes

- **Screen/View split and widget classes.** Follow explore_screen.dart:23-44. Sub-widgets are private `StatelessWidget` classes at the bottom of the file, and widgets specific to one state go in `home/widgets/`.
- **Extract `onTap` into a named method.** The handoff to the full-screen feed becomes `_openVideoFeed` on the view. The session-store, navigation and merge logic stays in the view; it does not move into the bloc. This is the most fragile behavior, and the bloc does not need to know about navigation.
- **Strings into `AppStrings`.** This includes the two slightly different versions of the onboarding copy (lines 104-107 and 333-336). Keep the wording users currently see in each place, so no visible copy changes.
- **Remove small leftovers:** the stale `TODO` at line 463 and the `HomeFeedNativeAdCard` wrapper, if it is used only by home.

### Bug fixes (separate commits, user-approved)

1. **Stuck pagination flag.** Today the flag is set in the load-more handler and cleared in the fetch handler's `finally`, guarded by `offset > 0`. A refresh that happens during load-more can leave it stuck. This is fixed by the `_fetchFeed` consolidation above.
2. **Raw error text.** Users currently see messages like `'Failed to load feed: $e'`. Replace these with generic copy from `AppStrings` and log the details instead, as the profile refactor did.

### Behaviors that must be preserved

Each needs an existing or new test:

- **Pull-to-refresh.** `_onRefresh` subscribes to the bloc stream before adding the event. The existing test at home_screen_test.dart:173 covers this.
- **Grid stays visible during load-more.** The existing test at home_screen_test.dart:111 covers this.
- **Ad slots.** The first ad is inserted at index 4 and then every 8 videos, with `slotIndex: sectionIndex`.
- **Onboarding.**
  - The first-card key and the `AppOnboardingTarget` stay on `globalIndex == 0`.
  - The one-shot `_hasAttemptedHomeOnboarding` guard stays.
  - The tour only triggers on `offset == 0` loads.
- **Grid-to-fullscreen handoff:**
  - `takeSession` runs after the pushed route pops.
  - Merging happens only for a longer list whose start matches the current list, and is skipped while pagination is in flight.
  - The `_revealVideo` `setState` happens before `revealFeedGridItem` runs.
- **Missing profile.** On `NoUserProfile` the screen calls `context.go('/username-setup')` and renders a fallback body.
- **Scrolling and haptics.**
  - Load-more triggers at 500px from the bottom of the scroll.
  - The `mediumImpact` haptic fires on refresh, retry and explore.
- **Signed-out users.** When `hasFullAccountAccess == false`, the profile fetch is skipped.

### Tests

- Update `test/bloc/home_bloc_test.dart` and `test/screens/home/home_screen_test.dart` for constructor injection and the new `isLoadingMore` flag.
- Add tests where coverage is missing and the refactor touches the code:
  - the `NoUserProfile` redirect;
  - ad-slot positions;
  - section chunking;
  - the stuck-flag regression.

### Delivery

- One focused PR on `refactor/home-screen-cleanup`, roughly 6 conventional commits.
- Each commit leaves the tests green.

## Open Questions

- Is `HomeFeedNativeAdCard` used anywhere besides home? If explore or video_feed import it, leave it in place.
- `HomeBloc` is created separately by two routes (app_router.dart:447 and :684). Should the stateless `HomeScreen` own `BlocProvider` creation, as explore does, or should the router keep providing it? This changes only where the code lives, not behavior; the planning phase should check what explore's router wiring does.

### Deferred follow-ups (not in this PR)

- **Onboarding never starts on remount.** If the bloc is already `FeedLoaded` when the screen remounts, the tour never starts. The fix would use profile's `initState` post-frame pattern. This was deferred because it is a behavior change.
- **Duplicated code across home and explore:**
  - the ad-insertion constants;
  - section chunking;
  - the error and empty widgets;
  - the 3–4 copies of `formatViewCount`.
- **`HomeFeedService` cleanup.** Inline it or give it a typed `HomeFeedPage` return. This touches the video_feed cubit.
- **Profile caching.** Move the profile cache population out of `HomeBloc` and into an auth or session layer.
- **Lints.** Enable `avoid_print` or move to `very_good_analysis`.
