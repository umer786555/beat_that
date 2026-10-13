---
title: "feat: replace content-loading spinners with shimmer skeletons app-wide"
type: feat
date: 2026-10-13
---

## feat: replace content-loading spinners with shimmer skeletons app-wide - Standard

Part 3 of 3. See the [umbrella plan](2026-10-13-refactor-explore-screen-polish-plan.md).

## Dependencies

- **Part 1 must be merged first.** This part reuses `FeedGridSkeletonSliver` and the reduced-motion `BeatShimmerFill` from Part 1.
- **Independent of Part 2.** It can merge before or after it.
- Branch: `feat/app-shimmer-sweep`, created from `main` after Part 1 merges.

## Overview

Apply one rule across the app:

- use `BeatShimmerFill` when **content with a known shape** is loading (thumbnails, grids, list rows, ad slots);
- keep `CircularProgressIndicator` for **actions in progress** and video buffering.

Five call sites change, and one shared user-row skeleton is added.

## Problem Statement / Motivation

After Part 1, Explore and Home load with skeletons, but other content screens still use spinners. The app mixes the two loading languages with no rule behind which one appears where.

## Proposed Solution

### Swap to shimmer

| # | File | Today | Change |
|---|---|---|---|
| 1 | [category_details_screen.dart:409](../../lib/screens/sports_hub/category_details_screen.dart#L409) | `loadingBuilder` with a progress spinner on an 84×84 image | `loadingBuilder` returns `const BeatShimmerFill()` when `loadingProgress != null`. It is already clipped by the parent `ClipRRect(16)`. |
| 2 | [creator_profile_screen.dart:228-238](../../lib/screens/creator_profile/creator_profile_screen.dart#L228) | load-more `SliverToBoxAdapter` spinner | `FeedGridSkeletonSliver(itemCount: 2, gridDelegate: _gridDelegate, padding: …)`. This matches Home's two-card load-more, using the creator grid's own geometry (`2 / 12 / 0.78`). |
| 3 | [feed_native_ad_card.dart:245](../../lib/widgets/feed_native_ad_card.dart#L245) | 18 px spinner inside `SizedBox(height: _adContentHeight)` | `ClipRRect(BeatShimmerFill())` filling the same `SizedBox`. The height doesn't change, so grid reveal offsets are unaffected. The "Ad unavailable right now" text on failure stays. |
| 4 | [profile_connections_screen.dart:142](../../lib/screens/profile/connections/profile_connections_screen.dart#L142) | full-screen spinner while loading | `const UserRowSkeletonList()` |
| 5 | [blocked_users_screen.dart:184](../../lib/screens/settings/blocked_users_screen.dart#L184) | full-screen spinner while loading | `const UserRowSkeletonList()` |

### `FeedGridSkeletonSliver` gains an optional delegate: `lib/widgets/feed_grid_skeleton_sliver.dart`

Add `this.gridDelegate = kFeedGridDelegate`. This is the first caller with different geometry (the creator profile), so the parameter is justified now and wasn't added in Part 1.

To avoid repeating the creator profile's delegate, extract it to a `static const _gridDelegate` in `creator_profile_screen.dart` and use it in both the `SliverGrid` and the skeleton.

### Shared user-row skeleton: `lib/widgets/user_row_skeleton_list.dart` (new)

```dart
// lib/widgets/user_row_skeleton_list.dart
/// Placeholder list for screens that load rows of users (avatar + name + subtitle).
class UserRowSkeletonList extends StatelessWidget {
  const UserRowSkeletonList({super.key, this.itemCount = 8});
  final int itemCount;
  // Semantics(label: 'Loading users') >
  // ListView.builder(physics: NeverScrollableScrollPhysics(), padding: 16h/8v,
  //   itemBuilder: Row(ClipOval(SizedBox.square(44, BeatShimmerFill())), 12,
  //     Column(ClipRRect(r6, SizedBox(h12, w140, BeatShimmerFill())), 8,
  //            ClipRRect(r6, SizedBox(h10, w90, BeatShimmerFill())))))
}
```

Before building, check the loaded row layout in both screens (avatar size, padding) and match it, so content doesn't jump when it arrives.

### Keep as spinners (no change)

- Button busy states: follow, unblock (`blocked_users_screen.dart:121`), the settings toggles, auth buttons, and the rating and report sheets.
- The approval-pending badge and the deleting overlay in `profile_video_grid_item.dart`.
- Video buffering in `pooled_video_surface.dart` and the feed pages.
- The upload progress bar in `title_input_bottom_sheet.dart`.

## Technical Considerations

- **Presentation only.** No bloc or state changes.
- **Accessibility:** skeletons carry a semantics label. Reduced motion is already handled in `BeatShimmerFill` (Part 1).
- **Performance:** at most 8 rows or 2 cards animate at once, and each is removed when content arrives.

## Tests

- [ ] `test/widgets/user_row_skeleton_list_test.dart` (new): `BeatShimmerFill` `findsWidgets`, `CircularProgressIndicator` `findsNothing`, and the "Loading users" semantics label is present.
- [ ] `test/widgets/feed_grid_skeleton_sliver_test.dart` (created in Part 1; extend it): with a custom `gridDelegate`, the rendered card aspect ratio matches it (`tester.getSize`).
- [ ] No screen tests exist for the five touched screens. Building screen harnesses for them is out of scope, so cover them with the grep criteria and the manual check below.

## Success Criteria

```success-criteria
GOAL: Every content-loading placeholder outside the video feeds uses BeatShimmerFill-based skeletons, while action and buffering spinners stay unchanged.

SUCCESS CRITERIA:
- The five content-loading sites no longer use CircularProgressIndicator (each of the first four files has exactly one spinner on main, and all of them are content-loading; blocked_users keeps its unblock-button spinner, so only its full-screen loading body is checked) | verify: ! grep -q "CircularProgressIndicator" lib/screens/sports_hub/category_details_screen.dart lib/screens/creator_profile/creator_profile_screen.dart lib/widgets/feed_native_ad_card.dart lib/screens/profile/connections/profile_connections_screen.dart && ! grep -q "body: const Center(child: CircularProgressIndicator())" lib/screens/settings/blocked_users_screen.dart
- Shared user-row skeleton exists and is used by both user-list screens | verify: flutter test test/widgets/user_row_skeleton_list_test.dart && grep -q "UserRowSkeletonList" lib/screens/profile/connections/profile_connections_screen.dart && grep -q "UserRowSkeletonList" lib/screens/settings/blocked_users_screen.dart
- Skeleton sliver honours a custom grid delegate and creator profile uses it | verify: flutter test test/widgets/feed_grid_skeleton_sliver_test.dart && grep -q "FeedGridSkeletonSliver" lib/screens/creator_profile/creator_profile_screen.dart
- Action/buffering spinners are untouched | verify: git diff --quiet $(git merge-base main HEAD) -- lib/widgets/pooled_video_surface.dart lib/widgets/title_input_bottom_sheet.dart $(find lib -name profile_video_grid_item.dart)
- Touched code is formatted and has no new analyzer warnings or errors | verify: flutter analyze --no-fatal-infos lib/screens/sports_hub/category_details_screen.dart lib/screens/creator_profile/creator_profile_screen.dart lib/widgets/feed_native_ad_card.dart lib/screens/profile/connections/profile_connections_screen.dart lib/screens/settings/blocked_users_screen.dart lib/widgets/user_row_skeleton_list.dart lib/widgets/feed_grid_skeleton_sliver.dart test/widgets && dart format --output=none --set-exit-if-changed lib/widgets/user_row_skeleton_list.dart lib/widgets/feed_grid_skeleton_sliver.dart test/widgets/user_row_skeleton_list_test.dart test/widgets/feed_grid_skeleton_sliver_test.dart
- Full suite stays green | verify: flutter test
- Skeletons look right on device | verify: manual 1. Open a category details screen on a slow network (Network Link Conditioner / emulator throttling): images show shimmer, not spinners. 2. Scroll a creator profile to load more: two shimmer cards matching the creator grid appear. 3. Scroll Home/Explore to an ad slot before it loads: the slot shimmers at its final height; with ads disabled it shows "Ad unavailable right now". 4. Open Followers/Following and Settings > Blocked Users: shimmer rows match the loaded row layout with no jump. 5. Tap Unblock: the button still shows its spinner. 6. Repeat 1-4 in dark mode.

NON-GOALS:
- Changing action, upload-progress or video-buffering spinners
- Screen-level widget test harnesses for the five touched screens
- Changing loaded-state layouts of the touched screens

VERIFICATION COMMAND: flutter test && ! grep -q "CircularProgressIndicator" lib/screens/sports_hub/category_details_screen.dart lib/screens/creator_profile/creator_profile_screen.dart lib/widgets/feed_native_ad_card.dart lib/screens/profile/connections/profile_connections_screen.dart && ! grep -q "body: const Center(child: CircularProgressIndicator())" lib/screens/settings/blocked_users_screen.dart && grep -q "UserRowSkeletonList" lib/screens/profile/connections/profile_connections_screen.dart && grep -q "UserRowSkeletonList" lib/screens/settings/blocked_users_screen.dart && grep -q "FeedGridSkeletonSliver" lib/screens/creator_profile/creator_profile_screen.dart && git diff --quiet $(git merge-base main HEAD) -- lib/widgets/pooled_video_surface.dart lib/widgets/title_input_bottom_sheet.dart $(find lib -name profile_video_grid_item.dart) && flutter analyze --no-fatal-infos lib/screens/sports_hub/category_details_screen.dart lib/screens/creator_profile/creator_profile_screen.dart lib/widgets/feed_native_ad_card.dart lib/screens/profile/connections/profile_connections_screen.dart lib/screens/settings/blocked_users_screen.dart lib/widgets/user_row_skeleton_list.dart lib/widgets/feed_grid_skeleton_sliver.dart test/widgets
```

## Success Metrics

- Spinners remain only for user actions, uploads and video buffering.

## Dependencies & Risks

- **Depends on:** Part 1 merged (`FeedGridSkeletonSliver`, reduced-motion `BeatShimmerFill`).
- **Risk: a broad spinner grep.** Research confirmed that `category_details_screen.dart`, `creator_profile_screen.dart`, `feed_native_ad_card.dart` and `profile_connections_screen.dart` each contain exactly one `CircularProgressIndicator`, the content-loading one being replaced. If a later rebase brings in an action spinner, narrow the criterion; don't remove that spinner.
- **Risk: user-row skeleton height doesn't match the loaded rows,** causing a jump. Mitigation: match the measured row layout (manual step 4).

## References & Research

- Rule and site list: brainstorm "App-wide shimmer sweep (PR 3)" in [2026-10-13-explore-screen-polish-brainstorm-doc.md](../brainstorm/2026-10-13-explore-screen-polish-brainstorm-doc.md)
- Existing `BeatShimmerFill` users: [thumbnail_grid_item.dart:54](../../lib/screens/edit_thumbnail/widgets/thumbnail_grid_item.dart#L54), [hub_grid_loading_view.dart:82](../../lib/widgets/hub_grid_loading_view.dart#L82), [video_thumbnail_item.dart:98](../../lib/screens/profile/widgets/video_thumbnail_item.dart#L98)
