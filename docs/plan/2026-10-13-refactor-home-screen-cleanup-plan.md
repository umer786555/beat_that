---
title: "refactor: home screen and HomeBloc cleanup"
type: refactor
date: 2026-10-13
brainstorm: docs/brainstorm/2026-10-13-home-screen-refactor-brainstorm-doc.md
branch: refactor/home-screen-cleanup
---

## refactor: home screen and HomeBloc cleanup - Standard

## Overview

This refactor makes the home grid feed easier to maintain. It covers [home_screen.dart](../../lib/screens/home/home_screen.dart) (495 lines) and [home/bloc/](../../lib/screens/home/bloc/), and keeps the user experience the same. It brings home in line with the explore (`8aba9a9`) and profile (`ffc0af1`) refactors:

- `HomeScreen` provides the bloc and builds a public `HomeView`.
- Private widget classes replace the `_buildX()` helpers.
- Copy moves into `AppStrings`.
- `HomeBloc` becomes the only place that holds feed state.

Two latent bugs are fixed, each in its own commit:

1. **Pagination after refresh.** Today the pagination flag can get stuck, and a page requested before a refresh can still land after it. The fix stops the flag sticking and discards that stale page.
2. **Raw error text.** Users see raw exception text on the error screen. It becomes generic copy, and the details are logged instead.

## Problem Statement / Motivation

- **The widget keeps its own copy of the feed.** `_lastLoadedVideos`, `_lastCursor` and `_lastHasMoreContent` ([home_screen.dart:36-38](../../lib/screens/home/home_screen.dart#L36-L38)) exist only because pagination emits `FeedLoading`, which drops the video list.
- **The bloc copies its own state too.** It holds `_allFeedVideos`, `_seenFeedVideoIds`, `_feedCursor` and `_hasMoreFeedContent` alongside the same data in `FeedLoaded`.
- **Events re-dispatch other events.** Refresh and LoadMore re-dispatch `FetchFeedEvent` ([home_bloc.dart:172](../../lib/screens/home/bloc/home_bloc.dart#L172), [:206](../../lib/screens/home/bloc/home_bloc.dart#L206)).
- **The in-flight flag is set and cleared in different handlers.** It is set in one handler and cleared in another, guarded by `offset > 0` ([home_bloc.dart:147-151](../../lib/screens/home/bloc/home_bloc.dart#L147-L151)). If load-more runs while the list is empty, for example straight after a refresh, the offset is 0 and the flag never clears.
- **Bloc handlers run concurrently.** The project has no `bloc_concurrency` dependency. A load-more response that arrives after a refresh is appended to the fresh list and replaces its cursor.
- **Raw exceptions reach the UI.** For example: `'Failed to load feed: $e'`.
- **Dead code:**
  - the unreachable `try/catch` blocks in Refresh and LoadMore;
  - the `UserProfileLoaded` state, which no UI reads;
  - the unused `limit = 50` default;
  - 14 `print()` calls (14 `avoid_print` infos);
  - the stale `TODO` at line 463.

## Proposed Solution

### Decisions

| # | Decision | Source |
|---|----------|--------|
| D1 | Keep sealed `Equatable` states and match the explore/profile pattern. A single `HomeState` with a status enum was rejected. | Brainstorm |
| D2 | `HomeBloc` takes optional named services (`PreferencesService`, `SupabaseService`, `HomeFeedService`, `AuthService`), each defaulting to `locator<>()`, like [profile_bloc.dart:26-36](../../lib/screens/profile/bloc/profile_bloc.dart#L26-L36). Tests stop registering GetIt singletons. | Brainstorm |
| D3 | `HomeScreen` is a `StatelessWidget` that owns `BlocProvider(create: (_) => HomeBloc()..add(const InitialEvent()))`, as [explore_screen.dart:23-37](../../lib/screens/explore/explore_screen.dart#L23-L37) does. Both routes, [app_router.dart:446-449](../../lib/routes/app_router.dart#L446-L449) and [:682-686](../../lib/routes/app_router.dart#L682-L686), become `const HomeScreen()`. Each route still gets its own bloc, so behavior doesn't change. | Brainstorm open question → resolved |
| D4 | **`HomeView` is public.** Tests pump it under `BlocProvider<HomeBloc>.value` with `MockHomeBloc`. This is VGV's Page/View convention, and it keeps the `whenListen` tests that script exact state sequences. | User (overrides the brainstorm's private `_HomeView`) |
| D5 | **Delete `FetchFeedEvent`.** Initial, Refresh and LoadMore call a private `_fetchFeed(emit, {FeedLoaded? appendTo})`. Passing `null` fetches the first page; passing the current `FeedLoaded` appends to it. Bloc tests move to `RefreshFeedEvent`, `LoadMoreFeedEvent` (with `seed:`) and `InitialEvent`. | User + VGV review |
| D6 | **The state is the single source of truth.** Delete `_allFeedVideos`, `_seenFeedVideoIds`, `_feedCursor`, `_hasMoreFeedContent` and `_isPaginationRequestInFlight`. Load-more and merge read videos, cursor and `hasMoreContent` from the current `FeedLoaded`. Seen IDs come from the current video IDs; today's set always equals them, because the old list is a prefix of every new one. As today, a page is filtered only against IDs already in the list; duplicates within one page are not removed. | Flow analysis #8 + simplicity |
| D7 | **`FeedLoaded.isLoadingMore` is the in-flight guard.** Load-more emits `FeedLoaded(…, isLoadingMore: true)` before its first `await`. `isLoadingMore` is in `props`; without it, the `false` state after an empty page would equal the `true` state and be dropped. | Brainstorm + flow analysis #2 |
| D8 | **Generation guard.** `int _feedGeneration` increases on every first-page fetch (Initial and Refresh). `_fetchFeed` records it before the `await`; if it has changed, the response is discarded. This fixes the stuck flag and the stale-page race. | User (included in bug fix 1) |
| D9 | `FeedLoading` has no fields and is only emitted for the first load and refresh. `FeedError` has no fields; the UI shows generic `AppStrings` copy and the bloc logs `debugPrint('[HOME] …: $e')`, as profile does. | Brainstorm + D5 |
| D10 | Keep the `catch` blocks that can run: the profile fetch in `_onInitial`, and the network call inside `_fetchFeed`. `_fetchFeed` catches its own errors, so a feed failure never reaches the profile `catch`. | Flow analysis #4 |
| D11 | **Preserve today's behavior when `isLoadingMore` is true.** The onboarding trigger, the `_onRefresh` completion check and `_revealVideo.shouldContinue` all ignore `isLoadingMore: true` states. | Flow analysis #5–7 |
| D12 | **Keep `HomeFeedNativeAdCard`.** It matches the per-placement wrapper pattern of `ExploreFeedNativeAdCard` and `SportDetailsNativeAdCard`. | User |
| D13 | **Keep the profile cache writes and `HomeFeedService`.** `ProfileBloc` reads that cache through `fetchUserProfile`, and the video_feed cubit uses `HomeFeedService`. | Brainstorm |
| D14 | A load-more failure still emits `FeedError`, and the full-screen error replaces the grid, as today. Retry sends `RefreshFeedEvent`, which skips the profile step, as today. | Preserve behavior |
| D15 | Keep `FeedLoaded.offset`. The simplicity review suggested replacing `offset == 0` with `videos.isEmpty`. But the brainstorm requires the tour to trigger only on `offset == 0` loads, and `offset` also tells a remount that sees an appended page apart from a first page. | Brainstorm (review suggestion declined) |
| D16 | Keep `HomeFeedMessage` as a public widget in `home/widgets/`. The simplicity review suggested a private class, but the brainstorm and explore's `widgets/explore_error_state.dart` put state widgets there. | Brainstorm (review suggestion declined) |

### Bloc shape (pseudo code)

This is the end state after Phase 3. In Phase 2, the `FeedError` emits still pass `message:`, and Phase 3 removes the field.

```dart
// lib/screens/home/bloc/home_bloc.dart
import 'package:flutter/foundation.dart'; // debugPrint (added in Phase 1)

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    PreferencesService? preferencesService,
    SupabaseService? supabaseService,
    HomeFeedService? homeFeedService,
    AuthService? authService,
  }) : _preferencesService = preferencesService ?? locator<PreferencesService>(),
       /* …same for the other three… */
       super(const HomeInitial()) {
    on<InitialEvent>(_onInitial);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
    on<MergeVideoFeedSessionEvent>(_onMergeVideoFeedSession);
  }

  static const int _pageSize = 24;

  /// Bumped on every first-page fetch so an older in-flight page is dropped.
  int _feedGeneration = 0;

  Future<void> _onInitial(InitialEvent event, Emitter<HomeState> emit) async {
    try {
      await _preferencesService.clearUserProfile();
      if (_authService.hasFullAccountAccess()) {
        final profile = await _supabaseService.fetchUserPersonalProfile();
        if (profile == null) {
          emit(const NoUserProfile());
          return;
        }
        await _preferencesService.saveUserProfile(profile);
      }
    } catch (e) {
      debugPrint('[HOME] Failed to load user profile: $e');
      emit(const FeedError());
      return;
    }
    await _fetchFeed(emit);
  }

  Future<void> _onRefreshFeed(RefreshFeedEvent event, Emitter<HomeState> emit) =>
      _fetchFeed(emit);

  Future<void> _onLoadMoreFeed(
    LoadMoreFeedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded ||
        current.isLoadingMore ||
        !current.hasMoreContent) {
      return;
    }
    await _fetchFeed(emit, appendTo: current);
  }

  /// Fetches the first page, or the next page after [appendTo].
  Future<void> _fetchFeed(Emitter<HomeState> emit, {FeedLoaded? appendTo}) async {
    final generation = appendTo == null ? ++_feedGeneration : _feedGeneration;
    emit(appendTo == null
        ? const FeedLoading()
        : FeedLoaded(/* appendTo's fields */, isLoadingMore: true));
    try {
      final page = await _homeFeedService.getHomeFeedContinuation(
        cursor: appendTo?.nextCursor ?? const HomeFeedCursor.initial(),
        limit: _pageSize,
      );
      if (generation != _feedGeneration) return; // a refresh superseded this
      final existing = appendTo?.videos ?? const <SportVideo>[];
      final existingIds = {for (final video in existing) video.id};
      final fresh = [
        for (final video in videosOf(page))
          if (!existingIds.contains(video.id)) video,
      ];
      emit(FeedLoaded(
        videos: [...existing, ...fresh],
        offset: existing.length,
        hasMoreContent: page['hasMoreContent'] as bool,
        nextCursor: page['nextCursor'] as HomeFeedCursor,
      ));
    } catch (e) {
      if (generation != _feedGeneration) return;
      debugPrint('[HOME] Failed to load feed: $e');
      emit(const FeedError());
    }
  }

  // _onMergeVideoFeedSession: same rules as today, reading from `state`:
  // ignore unless state is FeedLoaded && !isLoadingMore && the session list is
  // longer && its prefix matches; then emit FeedLoaded(videos: session,
  // offset: previous length, cursor/hasMore from the session).
}
```

```dart
// lib/screens/home/bloc/home_state.dart
final class FeedLoaded extends HomeState {
  const FeedLoaded({
    required this.videos,
    this.offset = 0,
    this.hasMoreContent = true,
    this.nextCursor = const HomeFeedCursor.initial(),
    this.isLoadingMore = false,
  });
  // …
  @override
  List<Object> get props => [videos, offset, hasMoreContent, nextCursor, isLoadingMore];
}
// HomeInitial, NoUserProfile, FeedLoading, FeedError: const, no fields.
```

### UI shape

This is guidance. The required outcome is no `_buildX` helpers, widget classes, and a sealed `switch`. The implementer may merge or rename the private widgets if that reads better.

```text
lib/screens/home/home_screen.dart
  HomeScreen (Stateless)  → BlocProvider(HomeBloc()..add(InitialEvent)) → HomeView
  HomeView (Stateful, public)
    _HomeViewState: scroll controller, onboarding guard and keys, reveal key/index
      _onScroll, _onRefresh, _maybePresentHomeOnboarding, _showHomeOnboardingIntro,
      _openVideoFeed(FeedLoaded feed, int index), _revealVideo
      build → Scaffold + BlocConsumer with a sealed `switch` on HomeState
  _FirstLoadSkeleton           (exists)
  _MissingProfileBody          (NoUserProfile fallback)
  _RefreshableBody             (was _buildRefreshableBody)
  _HomeFeedGrid                (was _buildFeedGrid; takes FeedLoaded + callbacks)
  _HomeFeedSectionSliver       (was _buildVideoSectionSliver)
  _HomeFeedSection + _chunkFeedSections(videos)   (pure, not a widget)

lib/screens/home/widgets/home_feed_message.dart
  HomeFeedMessage(icon, iconColor, title, message, actionIcon, actionLabel, onAction)
    → replaces _buildErrorState and _buildEmptyState. The button fires mediumImpact, then onAction.
    → The message always gets the error state's 32px horizontal padding. The empty-state text wraps
      slightly narrower than today; this is the one accepted visual change (user-approved).
```

Builder `switch` (preserves today's mapping):

| State | Body |
|-------|------|
| `HomeInitial`, `FeedLoading` | `_FirstLoadSkeleton` |
| `NoUserProfile` | `_MissingProfileBody` (the listener calls `context.go('/username-setup')`) |
| `FeedError` | `_RefreshableBody(HomeFeedMessage(error…, onAction: Refresh))` |
| `FeedLoaded` with empty videos and `offset == 0` | `_RefreshableBody(HomeFeedMessage(empty…, onAction: go('/explore')))` |
| `FeedLoaded` | `_HomeFeedGrid`. Shows the 2-item skeleton row when `isLoadingMore` |

Listener: `NoUserProfile` → `context.go('/username-setup')`. `FeedLoaded && offset == 0 && !isLoadingMore` → `_maybePresentHomeOnboarding(videos)`.

`_onRefresh` completion check: `(s is FeedLoaded && !s.isLoadingMore) || s is FeedError || s is NoUserProfile`.

`_revealVideo.shouldContinue`: `mounted && s is FeedLoaded && !s.isLoadingMore && index < s.videos.length`.

`_onScroll` drops its `_lastHasMoreContent` check, because the bloc guard ignores extra events. The 500px trigger stays.

### New `AppStrings` (home section)

The wording is exactly what users see today. Both onboarding descriptions are kept as they are.

| Key | Value |
|-----|-------|
| `home` | `Home` |
| `homeOnboardingIntroTitle` | `This is your Home feed` |
| `homeOnboardingIntroDescription` | `Home is where Beat That will surface clips based on what you watch, who you follow, and the sports you engage with.` |
| `homeOnboardingFirstVideoTitle` | `Open your feed` |
| `homeOnboardingFirstVideoStepDescription` | `Tap any clip to jump into the full feed. Home will learn from what you watch and show you more of it here.` (line 106) |
| `homeOnboardingFirstVideoTargetDescription` | `Tap any clip to jump into the full feed. Home learns from what you watch and uses that to improve recommendations.` (line 336) |
| `homeProfileNotFoundTitle` | `Profile not found` |
| `homeProfileNotFoundMessage` | `Please set up your profile to continue` |
| `homeFeedErrorTitle` | `Failed to load videos` |
| `homeEmptyTitle` | `No videos yet` |
| `homeEmptyMessage` | `Your Home feed will learn from what you watch\nand who you follow. Explore a few clips to start shaping it.` |
| `explore` | `Explore` |

The error body reuses the existing `AppStrings.somethingWentWrongPleaseTryAgain`, and the button reuses `AppStrings.retry`.

## Technical Considerations

- **Concurrency.** Handlers stay concurrent (no transformer is added). Correctness relies on two things:
  1. The `isLoadingMore: true` emit happens synchronously before the first `await`, so a second load-more sees it.
  2. The generation check after each `await`.
- **Equatable.** `isLoadingMore` must be in `props` (D7).
- **Behavior parity.**
  - Ad insertion: the first ad goes after 4 videos, then one after every 8, with `slotIndex: sectionIndex`, and none after the last section.
  - The onboarding first-card key stays on `globalIndex == 0`.
  - Haptics stay on refresh, retry and explore.
  - The handoff order stays the same: `takeSession` after the pop → merge → `_revealVideo` `setState` → `revealFeedGridItem`.
- **Known behavior that is not changed:**
  - An empty page with `hasMore: true` re-requests on every scroll near the bottom.
  - If the bloc closes mid-refresh, `_onRefresh`'s `firstWhere` throws.
  - Refresh shows the full skeleton, replacing the grid.
- **Security.** Bug fix 2 stops exception text, which can include backend details, from reaching the UI.

## Implementation Phases

Scope review: no split is needed. All the work is in `lib/screens/home`, plus the router and strings; it is roughly 700–900 changed lines, mostly test churn and mechanical moves. If the PR feels heavy, Phase 1 could land alone.

Each phase is one conventional commit on `refactor/home-screen-cleanup`, and the tests pass after each one.

### Phase 1: Inject HomeBloc services and drop dead bloc code

- **Status:** Done
- **Scope:**
  - Add constructor injection (D2).
  - Delete `UserProfileLoaded`, the dead `try/catch` in Refresh and LoadMore, and the `limit = 50` default. The `offset ?? 0` in `FeedError.props` stays until Phase 3 deletes the field, because removing it alone would mean retyping `props`.
  - Remove the `print`s that only report progress, and turn the ones in reachable `catch` blocks into `debugPrint('[HOME] …')`. Import `flutter/foundation.dart`.
  - In `home_bloc_test.dart`:
    - Pass the mocks through the constructor and drop GetIt.
    - Add a `buildBloc()` helper and use `build: buildBloc` in every test; remove the shared `homeBloc` from `setUp` and `tearDown`.
  - Rewrite the `UserProfileLoaded` widget test as "shows the skeleton in `HomeInitial`".
- **Commit:** `refactor: inject HomeBloc services and drop dead code`
- **Files touched:** `lib/screens/home/bloc/home_bloc.dart`, `lib/screens/home/bloc/home_state.dart`, `lib/screens/home/bloc/home_event.dart`, `lib/screens/home/home_screen.dart` (remove the `UserProfileLoaded` reference), `test/bloc/home_bloc_test.dart`, `test/screens/home/home_screen_test.dart`
- **Acceptance criteria:**
  - No `print(` or `UserProfileLoaded` remains in `home_screen.dart` or `home/bloc/`.
  - The bloc tests construct `HomeBloc(...)` with mocks and never touch GetIt.
- **Validation:** `flutter test test/bloc/home_bloc_test.dart test/screens/home && ! grep -rn "print(\|UserProfileLoaded" lib/screens/home/home_screen.dart lib/screens/home/bloc && ! grep -n "GetIt\|registerSingleton" test/bloc/home_bloc_test.dart`

### Phase 2: Fix pagination state (bug fix 1)

- **Status:** Done
- **Scope:**
  - Delete `FetchFeedEvent` and add `_fetchFeed(emit, {FeedLoaded? appendTo})` (D5).
  - Make the state the single source of truth (D6), add `FeedLoaded.isLoadingMore` (D7) and the generation guard (D8).
  - Remove `FeedLoading`'s fields.
  - `FeedError` still takes `message:` in this phase.
  - In the widget, delete `_lastLoadedVideos`, `_lastCursor` and `_lastHasMoreContent`, render pagination from `FeedLoaded.isLoadingMore`, and apply D11.
- **Commit:** `fix: stuck pagination flag and stale pages after refresh`
- **Files touched:** `lib/screens/home/bloc/home_bloc.dart`, `lib/screens/home/bloc/home_event.dart`, `lib/screens/home/bloc/home_state.dart`, `lib/screens/home/home_screen.dart`, `test/bloc/home_bloc_test.dart`, `test/screens/home/home_screen_test.dart`
- **Tests (bloc), `test/bloc/home_bloc_test.dart`:**
  - [ ] Migrate the first-page `FetchFeedEvent` tests to `RefreshFeedEvent`. Rewrite the load-more and merge tests to start from `seed: () => FeedLoaded(videos: …, nextCursor: …)` instead of loading a first page and using `skip:`. Drop the tests that only made sense with a custom `limit`, such as "calls continuation with correct parameters" at offset 25.
  - [ ] **`InitialEvent`:**
    - Signed in with a profile: `saveUserProfile` is called with it, and the states are `[FeedLoading(), FeedLoaded(...)]`.
    - Signed in with no profile: `[NoUserProfile()]`, and `verifyNever(getHomeFeedContinuation)`.
    - Guest: `fetchUserPersonalProfile` is never called. This test exists today.
    - In every case, `clearUserProfile` is called once.
  - [ ] Load-more emits `[FeedLoaded(same videos, isLoadingMore: true), FeedLoaded(appended, offset: n)]`.
  - [ ] An empty or all-duplicate page still emits the `isLoadingMore: false` state.
  - [ ] Load-more is ignored when seeded with `HomeInitial`, `FeedLoading` or `FeedError`, when `hasMoreContent` is false, and when `isLoadingMore` is true. Expect `[]` and `verifyNever(getHomeFeedContinuation)`. Migrate the existing duplicate-load-more test.
  - [ ] **`group('refresh during load-more')`.** Use `blocTest` with an async `act`, two `Completer`s and an exact `expect:` list:
    - Stale page completes **before** the refresh fetch: `[FeedLoaded(seed, isLoadingMore: true), FeedLoading(), FeedLoaded(refreshed)]`.
    - Stale page completes **after** the refresh fetch: the same list, with nothing after it.
    - **Stuck flag:** after the refresh completes, a new `LoadMoreFeedEvent` calls the service with the refreshed cursor.
  - [ ] A load-more failure emits `FeedError`, and a later refresh recovers.
  - [ ] A merge during load-more is ignored (seed `isLoadingMore: true`). The existing merge tests still pass.
  - [ ] Duplicate IDs across pages are filtered.
- **Tests (widget), `test/screens/home/home_screen_test.dart`:**
  - [ ] Rewrite the test at line 111 to use `FeedLoaded(isLoadingMore: true)`: the grid stays and the 2-item skeleton row appears.
  - [ ] In the refresh test (around line 222), change `FeedLoading(offset: 0, isFirstLoad: true)` to `const FeedLoading()`.
  - [ ] Refresh does not complete on a `FeedLoaded(isLoadingMore: true)` emission.
  - [ ] Onboarding `startFlow` is called exactly once across `FeedLoaded(offset 0)` → `isLoadingMore: true` → `FeedLoaded(offset 2)`. This is a parity test: the `_hasAttemptedHomeOnboarding` guard alone would also make it pass.
- **Acceptance criteria:**
  - No `FetchFeedEvent`, `_lastLoadedVideos`, `_lastCursor`, `_lastHasMoreContent` or `_isPaginationRequestInFlight` remains in `lib/`.
  - The regression tests pass.
- **Validation:** `flutter test test/bloc/home_bloc_test.dart test/screens/home && ! grep -rnE "FetchFeedEvent|_lastLoadedVideos|_lastCursor|_lastHasMoreContent|_isPaginationRequestInFlight" lib`

### Phase 3: Generic error copy (bug fix 2)

- **Status:** Done
- **Scope:**
  - `FeedError` loses `message` and `offset`.
  - The error UI shows `AppStrings.homeFeedErrorTitle` with `AppStrings.somethingWentWrongPleaseTryAgain`.
  - The bloc logs details with `debugPrint`.
- **Commit:** `fix: show generic copy instead of raw feed errors`
- **Files touched:** `lib/screens/home/bloc/home_state.dart`, `lib/screens/home/bloc/home_bloc.dart`, `lib/screens/home/home_screen.dart`, `lib/constants/app_strings.dart`, `test/bloc/home_bloc_test.dart`, `test/screens/home/home_screen_test.dart`
- **Tests:**
  - [ ] Bloc: a profile fetch that throws emits `const FeedError()`, and so does a feed fetch that throws.
  - [ ] Widget test `'shows generic error copy'`: the error state shows `Failed to load videos` and `Something went wrong. Please try again.`, and never the exception text.
- **Acceptance criteria:**
  - `FeedError` has no fields.
  - No `$e` is interpolated into any emitted state.
- **Validation:** `flutter test test/bloc/home_bloc_test.dart test/screens/home`

### Phase 4: Screen/View split, widget classes and strings

- **Status:** Done
- **Scope:**
  - Split the screen into `HomeScreen` and a public `HomeView` (D3, D4), and simplify both router entries.
  - Replace the `_buildX()` helpers with private widget classes and a sealed `switch`.
  - Add `HomeFeedMessage` in `home/widgets/`.
  - Move all copy into `AppStrings`.
  - Extract `_openVideoFeed`.
  - Remove the stale `TODO`.
- **Commit:** `refactor: split home screen into widgets and move copy to AppStrings`
- **Files touched:** `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/home_feed_message.dart` (new), `lib/routes/app_router.dart`, `lib/constants/app_strings.dart`, `test/screens/home/home_screen_test.dart`
- **Tests (widget), `test/screens/home/home_screen_test.dart`.** `buildTestApp` pumps `HomeView` under `BlocProvider.value`.
  - [ ] **Visible copy (`group('visible copy')`). Write this group first,** run it against the code before the strings move, and confirm it passes. Only then move the strings. Assert the literal strings, not `AppStrings`, so any wording change fails:
    - on screen: the empty title and message, the error title and body (the Phase 3 copy), the missing-profile title and message, the `Home` app bar, and the `Retry` and `Explore` labels;
    - onboarding: capture the `OnboardingFlowRequest` passed to the mocked `startFlow`, and assert the step's title (`Open your feed`) and its description (the line 106 wording);
    - onboarding: read the first card's `AppOnboardingTarget` and assert its `title` and `description` (the line 336 wording).
    The intro sheet copy stays covered by manual step 7.
  - [ ] **`NoUserProfile`.** Emitting it navigates to `/username-setup`; check `router.routerDelegate.currentConfiguration.uri.path`. Starting in it renders the fallback.
  - [ ] **`group('ad slots')` (covers chunking too).** Use 13 videos; register a mock `AdMobConsentService` where `canRequestAds` is false. Check `CustomScrollView.slivers`:
    - grid sections with 4, 8 and 1 children;
    - `HomeFeedNativeAdCard` slots 0 and 1, each after its section;
    - no ad after the last section.
    Also check that 12 videos give exactly 1 ad and 4 videos give none.
  - [ ] **Scroll.** Dragging to within 500px of the bottom adds `LoadMoreFeedEvent`.
  - [ ] **Retry.** Tapping it adds `RefreshFeedEvent` and fires `mediumImpact`.
  - [ ] **Explore.** Tapping it navigates to `/explore` and fires `mediumImpact`.
  - [ ] The existing refresh, empty and error tests still pass.
  - [ ] **`HomeScreen` wiring.** Register mock services in the locator (Preferences, Supabase, HomeFeed, Auth, Onboarding, AdMobConsent), with a guest auth stub and an empty page. Pump `HomeScreen`. `HomeView` renders, and `getHomeFeedContinuation` is called once, which proves `InitialEvent` was added. This replaces the router's `BlocProvider` coverage.
- **Acceptance criteria:**
  - No `_build[A-Z]` methods remain in `home_screen.dart`.
  - No hard-coded user-facing copy remains in home UI files.
  - `app_router.dart` never constructs `HomeBloc`.
- **Validation:** `flutter test test/screens/home && ! grep -n "_build[A-Z]" lib/screens/home/home_screen.dart && ! grep -nE "Text\('|'[A-Z][a-z]+ [a-z]" lib/screens/home/home_screen.dart lib/screens/home/widgets && ! grep -n "HomeBloc()" lib/routes/app_router.dart`

## Success Criteria

```success-criteria
GOAL: The home grid feed behaves as before, apart from the generic error body copy (bug fix 2) and slightly narrower empty-state padding. Its screen is a stateless HomeScreen plus a public HomeView built from widget classes, all copy is in AppStrings, HomeBloc is the only holder of feed state with injected services, and pagination can no longer get stuck or accept stale pages after a refresh.

SUCCESS CRITERIA:
- The full test suite passes (275 tests at baseline, plus the new ones) | verify: flutter test
- Touched files have no analyzer issues, including the 14 avoid_print infos fixed | verify: flutter analyze lib/screens/home/home_screen.dart lib/screens/home/bloc lib/screens/home/widgets lib/routes/app_router.dart lib/constants/app_strings.dart test/bloc/home_bloc_test.dart test/screens/home/home_screen_test.dart
- Touched files are formatted | verify: dart format --output=none --set-exit-if-changed lib/screens/home/home_screen.dart lib/screens/home/bloc lib/screens/home/widgets lib/routes/app_router.dart lib/constants/app_strings.dart test/bloc/home_bloc_test.dart test/screens/home/home_screen_test.dart
- Dead and duplicated state is gone | verify: ! grep -rnE "print\(|UserProfileLoaded|FetchFeedEvent|_lastLoadedVideos|_lastCursor|_lastHasMoreContent|_isPaginationRequestInFlight|_allFeedVideos|TODO" lib/screens/home/home_screen.dart lib/screens/home/bloc
- HomeBloc is constructor-injected, and its tests use no service locator | verify: ! grep -n "GetIt\|registerSingleton" test/bloc/home_bloc_test.dart
- HomeScreen provides the bloc, and the router no longer does | verify: flutter test test/screens/home/home_screen_test.dart --name "HomeScreen wiring" && ! grep -n "HomeBloc()" lib/routes/app_router.dart
- No _buildX helpers and no hard-coded copy in home UI | verify: ! grep -n "_build[A-Z]" lib/screens/home/home_screen.dart && ! grep -nE "Text\('|'[A-Z][a-z]+ [a-z]" lib/screens/home/home_screen.dart lib/screens/home/widgets
- Visible copy is unchanged (the tests assert literal strings) | verify: flutter test test/screens/home/home_screen_test.dart --name "visible copy"
- A refresh during load-more neither sticks the pagination guard nor lets stale pages in | verify: flutter test test/bloc/home_bloc_test.dart --name "refresh during load-more"
- Users never see raw exception text | verify: flutter test test/screens/home/home_screen_test.dart --name "generic error"
- Ad slots go after 4 videos and then every 8, with slotIndex = section index and none after the last section | verify: flutter test test/screens/home/home_screen_test.dart --name "ad slots"
- Each commit leaves the tests passing | verify: manual 1. For each of the 4 phase commits in `git log main..HEAD`, confirm /build ran and passed that phase's Validation command before committing.
- The app behaves the same on a device | verify: manual 1. Launch the app signed in; Home shows the skeleton, then the grid. 2. Scroll to the bottom; a 2-card skeleton row appears and more videos append. 3. Pull to refresh; the skeleton shows, then a fresh grid. 4. Scroll until load-more starts, then immediately pull to refresh; the fresh grid has no duplicated or out-of-order clips, and scrolling keeps paginating. 5. Tap a video, swipe a few, go back; the grid scrolls to that video. 6. Ads appear after the 4th video and then every 8. 7. With a fresh onboarding state, the Home intro and the first-card tour appear once. 8. In airplane mode, refresh; you see "Failed to load videos" and "Something went wrong. Please try again." with no exception text, and Retry with the network back restores the feed. 9. Sign in as a user without a profile; the app goes to username setup.

NON-GOALS:
- The home/video_feed subfeature (cubit, screen, page) and HomeFeedService's return type.
- Sharing ad chunking, error and empty widgets, or formatViewCount with explore.
- Moving profile cache population out of HomeBloc.
- Fixing onboarding on remount, the empty-page re-request loop, the full-skeleton-on-refresh behavior, or Retry skipping the profile step after a profile failure.
- Enabling very_good_analysis or changing analysis_options.yaml.

VERIFICATION COMMAND: flutter test && flutter analyze lib/screens/home/home_screen.dart lib/screens/home/bloc lib/screens/home/widgets lib/routes/app_router.dart lib/constants/app_strings.dart test/bloc/home_bloc_test.dart test/screens/home/home_screen_test.dart && dart format --output=none --set-exit-if-changed lib/screens/home/home_screen.dart lib/screens/home/bloc lib/screens/home/widgets lib/routes/app_router.dart lib/constants/app_strings.dart test/bloc/home_bloc_test.dart test/screens/home/home_screen_test.dart && ! grep -rnE "print\(|UserProfileLoaded|FetchFeedEvent|_lastLoadedVideos|_lastCursor|_lastHasMoreContent|_isPaginationRequestInFlight|_allFeedVideos|TODO" lib/screens/home/home_screen.dart lib/screens/home/bloc && ! grep -n "GetIt\|registerSingleton" test/bloc/home_bloc_test.dart && ! grep -n "HomeBloc()" lib/routes/app_router.dart && ! grep -n "_build[A-Z]" lib/screens/home/home_screen.dart && ! grep -nE "Text\('|'[A-Z][a-z]+ [a-z]" lib/screens/home/home_screen.dart lib/screens/home/widgets
```

Test naming contract: the `--name` filters above match the test descriptions or group names `visible copy`, `refresh during load-more`, `generic error`, `ad slots` and `HomeScreen wiring`. Use these exact strings. `flutter test` (the first command) runs all of them.

The hard-coded copy grep is a coarse guard: it catches capitalized multi-word single-quoted literals. The literal-string `visible copy` tests are what prove the wording is unchanged.

## Success Metrics

- `home_screen.dart` has no `_build*` helpers and no widget-side feed state.
- `HomeBloc` has one mutable field (`_feedGeneration`) instead of five.
- Zero `avoid_print` infos in `home_bloc.dart` (down from 14).
- New regression tests cover both pagination races.

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Test churn from deleting `FetchFeedEvent`: about 10 bloc tests | The rewrites are mechanical (Phase 2). Tests that only checked custom `limit` values are dropped; page size is a fixed constant. |
| Deriving the in-flight guard and seen IDs from the state changes the timing | The `isLoadingMore` emit happens before the first `await`. The existing duplicate-load-more test plus the new regression tests prove the guard. |
| Ad widget tests touch `locator<AdMobConsentService>` | Register a mock where `canRequestAds` is false, and inspect `CustomScrollView.slivers` instead of rendering offscreen ads. |
| The onboarding first-card key and target move into `_HomeFeedSectionSliver` | Pass `firstCardKey` down explicitly. The onboarding-once test and manual step 7 cover it. |
| Handoff ordering regresses during the `_openVideoFeed` extraction | Move the code verbatim, using the `FeedLoaded` snapshot at tap time instead of the `_last*` fields. The existing merge tests plus manual step 5 cover it. |
| An unrelated local edit to `analysis_options.yaml` is in the working tree (`analyzer.exclude`) | Not part of this plan. Leave it out of these commits. |

## References & Research

- **Brainstorm:** [docs/brainstorm/2026-10-13-home-screen-refactor-brainstorm-doc.md](../brainstorm/2026-10-13-home-screen-refactor-brainstorm-doc.md)
- **Explore Screen/View pattern:** [explore_screen.dart:23-44](../../lib/screens/explore/explore_screen.dart#L23-L44), PR #2 (`8aba9a9`)
- **Profile constructor injection and debugPrint logging:** [profile_bloc.dart:26-48](../../lib/screens/profile/bloc/profile_bloc.dart#L26-L48), PR #3 (`ffc0af1`)
- **Profile cache consumer:** [profile_bloc.dart:77](../../lib/screens/profile/bloc/profile_bloc.dart#L77)
- **Router entries:** [app_router.dart:446](../../lib/routes/app_router.dart#L446), [app_router.dart:682](../../lib/routes/app_router.dart#L682)
- **Ad wrapper pattern:** [home_feed_native_ad_card.dart](../../lib/widgets/home_feed_native_ad_card.dart), [explore_feed_native_ad_card.dart](../../lib/widgets/explore_feed_native_ad_card.dart), [feed_native_ad_card.dart](../../lib/widgets/feed_native_ad_card.dart) (`initState` reads `locator<AdMobConsentService>`)
- **Error widget reference:** [explore_error_state.dart](../../lib/screens/explore/video_feed/widgets/explore_error_state.dart)
- **Existing tests:**
  - [home_bloc_test.dart](../../test/bloc/home_bloc_test.dart) (563 lines; the duplicate-load-more test is at :335 and the merge group at :467)
  - [home_screen_test.dart](../../test/screens/home/home_screen_test.dart) (pagination test at :111; refresh-completion test at :173)
- **Baseline (2026-10-13):** `flutter test` gives 275 passed. Scoped analyze shows 14 `avoid_print` infos in `home_bloc.dart`. `home_event.dart` and `home_state.dart` are currently unformatted, so Phase 1 formats them.
- **External research:** skipped. The local patterns are strong, and the work uses no new libraries.
