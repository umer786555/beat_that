# Video playback profiling checklist

Run this before each release that touches video playback. It is a pre-release
gate, not a merge blocker. The Home and Explore feeds share one
`VideoPlayerPool` of at most 5 media_kit players
(`lib/services/video_playback/`); the single-video screen (`play-video`) adds
one more while it is open.

Profile **release or profile builds only**. Debug builds are much slower and
give misleading numbers.

## Device matrix

| Platform | Device | OS | RAM |
|----------|--------|----|-----|
| iOS | Any supported iPhone (iOS 16+) | | |
| Android | A low-end device | Android 12+ (minSdk 31) | 3–4 GB |

## 1. Confirm hardware decoding

`MediaKitPlaybackPlayer` logs mpv's `hwdec-current` in debug builds once a
video's first frame is decoded.

1. Run a **debug** build: `flutter run`.
2. Open the Home feed and let the first video load.
3. Look in the console for `MediaKitPlaybackPlayer hwdec-current: <value>`.
4. Expected values:
   - iOS: `videotoolbox`
   - Android: `mediacodec` (or `mediacodec-copy`)
   - `no` or an empty value means software decoding. Record the video's codec
     (for example, an HEVC `.mov` from an iPhone) and investigate before release.

## 2. iOS energy and memory (Xcode)

1. Run a **profile** build: `flutter run --profile`, or use Xcode's Product >
   Profile.
2. In Instruments, choose the **Energy Log** template and add the
   **Allocations** instrument.
3. Run a 10-minute session: about 200 swipes through the Home feed, mixing
   normal-pace swipes, back-swipes, and fast flings. Background and foreground
   the app twice, and open and close a creator profile twice.
4. Record:
   - The Energy Impact level during steady playback. Target: Low or Medium.
   - Whether memory plateaus. There should be no upward trend after the first
     few swipes.

## 3. Android energy and memory (Android Studio)

1. Run a **profile** build: `flutter run --profile`.
2. In Android Studio, open **View > Tool Windows > Profiler** and attach to the
   app process.
3. Run the same 10-minute session as on iOS.
4. Record:
   - The Energy profiler's level during steady playback.
   - Whether the Memory profiler's native and total memory plateau. There
     should be no upward trend over 200 swipes.
5. If memory doesn't plateau, lower `bufferSize` in `MediaKitPlaybackPlayer`
   from 8 MiB to 4 MiB and repeat.

## 4. Compare with the baseline

Compare each result with the `video_player` baseline recorded on `main` before
the media_kit migration. Energy impact should be no worse, and peak memory
should be in the same range.

## Results

| Date | Build | Device | hwdec-current | Energy (steady playback) | Memory plateaus? | Notes |
|------|-------|--------|---------------|--------------------------|------------------|-------|
| | | | | | | |
