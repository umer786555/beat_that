---
date: 2026-10-12
topic: media-kit-player-pool
---

# Migrate vertical video feeds from video_player to media_kit with a pooled-player architecture

## What We're Building

Replace `video_player` across the app with `media_kit` (libmpv). Both vertical feeds (Home and Explore) will be backed by a single app-scoped, fixed-size pool of reusable players. Today each feed cubit keeps a `Map<int, VideoPlayerController>` keyed by page index and creates and disposes a controller per page. The pool instead keys players by video source and swaps media with `player.open()` on an existing instance. It keeps a preload window of 2 videos ahead and 1 behind warm (playing at volume 0) and evicts by LRU. Eviction is synchronous, so a thumbnail replaces the video before the texture is destroyed.

The single-video screen (`play_uploaded_video`) and the shared `VideoEngagementTracker` also move off `video_player`, so the dependency can be removed. Design reference: VGV's diVine case study (https://verygood.ventures/blog/video-playback-flutter-feed/).

### Acceptance criteria (from the original brief)

1. **Instant swipes.** With a warm pool and preload, the next video starts with no visible loading spinner.
2. **No black screens**, including during very fast swiping. Every visible page shows either the video's first frame or a placeholder image, never an empty texture.
3. **Thermal and battery.** Over a long session:
   - live decoders stay at or below the pool size, with no leaked players;
   - players outside the preload window are released or paused;
   - all playback stops when the app is backgrounded;
   - hardware decoding is used, with the `hwdec` setting confirmed per platform.
   Verification needs a leak test that counts live `Player` instances across 200 swipes, plus a profiling checklist (Xcode Energy, Android Studio Profiler).
4. **Remove `video_player`** once the migration is complete.

### Definition of done

- Pool tests cover LRU eviction, reuse by source, preload window size, and background stop.
- The leak test passes.
- `test-quality-review-agent` and `architecture-review-agent` report no blocking issues.
- `/review` runs before the PR is opened.

## Why This Approach

We considered three architectures:

- **App-scoped pool service (chosen).** A plain Dart `VideoPlayerPool` in `lib/services/`, registered in `get_it` (`lib/service_locator.dart`) like the other services. It gives one global decoder cap, which is exactly what criterion 3 measures, and it can be tested in isolation.
- **One pool per feed cubit (rejected).** Simpler lifecycle, but with Home and Explore both in the navigation stack it allows 2× the pool size in live decoders. Keeping the cap would mean tearing down the hidden feed's pool, which throws away the warm buffers that are the point of pooling.
- **Pool as a Cubit (rejected).** High-frequency slot and player updates would go through `emit`. The reference design uses `ValueNotifier` to avoid exactly that rebuild cost.

A disk file cache (`file://` serving, a startup index, single-concurrency background pre-caching with shared in-flight downloads) is **deferred**. A warm pool plus preloading already meets criteria 1 and 2 within a session. A disk cache mainly saves data and helps cold starts and revisits after eviction, so adding it now is YAGNI. The pool's source input stays a plain URL so a cache can be added later without rework.

## Key Decisions

- **Scope covers every video_player user.** That means the Home feed cubit and page, the Explore feed cubit and screen, the `play_uploaded_video` bloc and screen, and `VideoEngagementTracker`. Criterion 4 can't be met otherwise.
- **One shared pool for both feeds.** It needs a small "active owner" concept: the visible feed claims the pool, and a feed covered by another route shows placeholders and reclaims the pool when it's visible again.
- **The single-video screen uses a plain media_kit `Player`, not the pool.** It plays one video, so pooling adds nothing. It still has to dispose correctly and count toward the leak test if it is open at the same time as a feed.
- **`VideoEngagementTracker` API change is approved.** `onPlaybackProgress(VideoPlayerValue)` becomes a small player-agnostic progress type (for example position, duration, and isPlaying), so the service no longer depends on any player package. The tracker test must be updated.
- **Pool key is the canonical `videoPath`, not the resolved URL.** Today `resolveVideoPlaybackUrl` returns stable public URLs, but a comment there says it may switch back to signed URLs. Signed URLs change on every fetch and would break reuse by key.
- **Placeholders use the existing `SportVideo.thumbnailUrl`.** Pages show the thumbnail until the first frame renders and whenever a slot is evicted, replacing the current black box with a spinner. The fallback when `thumbnailUrl` is null still needs deciding (see Open Questions).
- **A new lifecycle observer.** There is currently no `WidgetsBindingObserver` in the app. The pool observes lifecycle: on background it sets the foreground flag to false, pauses everything, and clears visibility state. On foreground it does not force-resume.
- **Disk cache is deferred** to a follow-up (see above).
- **No feed UI or behavior changes** beyond what the criteria require. Retry, error, chrome toggle, rating, and creator-profile behavior stay the same. `HomeVideoFeedPage.controller` changes type, but that widget is used only inside the home feed, so no API exposed to other screens changes.
- **Suggested PR split.** The plan-splitting agent makes the final call. This replaces the brief's split, because the scope now covers two feeds and the single-video screen:
  1. Add the `media_kit` dependency and `hwdec` config, `VideoPlayerPool` with lifecycle handling, the tracker progress type, pool unit tests, and the leak test.
  2. Wire the Home and Explore feeds to the pool, with thumbnail placeholders and `ValueNotifier`-per-index slots.
  3. Migrate `play_uploaded_video`, remove `video_player`, and add the profiling checklist doc.

## Open Questions

For the planning phase:

- **Research deliverable (required before the plan).** Run `official-docs-research-agent` with context7 on media_kit and the VGV guide. Mark each claim as verified from docs or as an assumption. Cover:
  - `open()` on an existing `Player`: does it reset the texture or `VideoController`, and how long does a switch take?
  - `hwdec` options on iOS (videotoolbox) and Android (mediacodec and mediacodec-copy) and their battery impact.
  - `VideoController` dispose and memory behavior, and whether one controller can survive many `open()` calls.
  - Known media_kit issues with fast source switching or black and stale frames, for example the previous video's last frame flashing before the new first frame.
  - API surface: `Player`, `VideoController`, the `Video` widget, `MediaKit.ensureInitialized()`, and the platform setup for `media_kit_libs_video`.
- **Pool size.** The brief asks the plan to choose one and justify it. A starting lean is 5: a window of 4 (1 behind, the current video, 2 ahead) plus 1 slack slot for LRU churn during fast swipes. This should be checked against per-instance libmpv memory on low-end Android.
- **Thumbnail fallback.** When `thumbnailUrl` is null or still loading, what should the page show: a dark gradient with no spinner, or the spinner only on a cold start? Criterion 1 forbids the spinner only when the pool is warm.
- **Codecs.** Sources are user-uploaded MP4s, not HLS, so the brief's "Baseline Profile HLS variant" point doesn't directly apply. Check what codec uploads produce, especially HEVC from iPhones. Older Android devices may lack a hardware HEVC decoder, which affects both playback and the `hwdec` and battery goals. This may become a follow-up rather than part of the migration.
- **Owner handoff details.** How does a feed know it's covered by another route (`RouteAware` versus the screen's own visibility signal), and what happens to the hidden feed's slots: kept warm but paused, or eligible for eviction first?
- **Looping and view tracking.** The current code calls `setLooping(true)` and attaches view-tracking listeners per controller. Map these to `PlaylistMode.single` and the media_kit position and playing streams, and make sure warm, muted preload players don't count as views.
- **Leak test mechanics.** How do we count live `Player` instances in a unit test? Options include injecting a player factory into the pool and counting create versus dispose, or using a fake `Player`. The plan needs to settle this.
