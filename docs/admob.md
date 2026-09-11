# AdMob Configuration

This project uses the Flutter `google_mobile_ads` plugin for Android and iOS ad delivery.

## Current Setup

- Plugin version: `google_mobile_ads: 9.0.0`
- Reason for pinning `9.0.0`: `9.1.0` introduced iOS Ad Preloading APIs and imports of `GoogleMobileAds_Beta.h`, which caused simulator build failures in this repo.
- Consent flow: Google UMP is required before any ad request.
- Live placements:
  - Home feed native ad slot
  - Home video feed interstitial ad
  - Explore feed native ad slot
  - Explore video feed interstitial ad
  - Sport details native ad slot

## Platform Configuration

### Android

- App ID is stored in [android/app/src/main/AndroidManifest.xml](/Users/umermalik/beat_that/android/app/src/main/AndroidManifest.xml).
- The app uses `google_mobile_ads` through Flutter; no manual Android SDK wiring is needed beyond the manifest App ID.

### iOS

- App ID is stored as `GADApplicationIdentifier` in [ios/Runner/Info.plist](/Users/umermalik/beat_that/ios/Runner/Info.plist).
- `SKAdNetworkItems` are included in [ios/Runner/Info.plist](/Users/umermalik/beat_that/ios/Runner/Info.plist) using Google's published list.
- `NSUserTrackingUsageDescription` is included in [ios/Runner/Info.plist](/Users/umermalik/beat_that/ios/Runner/Info.plist) because Google's iOS IDFA guidance requires it before the ATT alert can appear.
- CocoaPods configuration in [ios/Podfile](/Users/umermalik/beat_that/ios/Podfile) follows the official Flutter AdMob example shape:
  - `use_frameworks!`
  - `use_modular_headers!`

### iOS ATT and IDFA

Official Google flow for `google_mobile_ads: 9.0.0` on Flutter:

1. Keep the existing UMP startup flow in [lib/services/ad_mob_consent_service.dart](/Users/umermalik/beat_that/lib/services/ad_mob_consent_service.dart):
   - `requestConsentInfoUpdate()`
   - `loadAndShowConsentFormIfRequired()`
   - only request ads when `canRequestAds()` is `true`
2. In the AdMob console, create an **IDFA message** under Privacy and messaging for the iOS app.
3. Keep `NSUserTrackingUsageDescription` in [ios/Runner/Info.plist](/Users/umermalik/beat_that/ios/Runner/Info.plist).

Important behavior from Google's docs:

- On iOS, the UMP SDK shows the IDFA explainer message before the Apple ATT alert when an IDFA message exists in AdMob.
- If the user denies ATT, continue requesting ads normally; the Google Mobile Ads Flutter plugin does not send IDFA in the ad request.
- If App Store Connect privacy labels claim tracking, the AdMob IDFA message must actually be configured or App Review will not see the ATT prompt.

## Runtime Flow

- SDK initialization runs in [lib/main.dart](/Users/umermalik/beat_that/lib/main.dart).
- Consent state is managed by [lib/services/ad_mob_consent_service.dart](/Users/umermalik/beat_that/lib/services/ad_mob_consent_service.dart).
- Privacy choices can be reopened from [lib/screens/settings/settings_screen.dart](/Users/umermalik/beat_that/lib/screens/settings/settings_screen.dart) when UMP requires a revocation entry point.

Official flow followed:

1. `requestConsentInfoUpdate()` on app launch
2. `loadAndShowConsentFormIfRequired()`
3. only load ads when `canRequestAds()` is `true`
4. on iOS, UMP can only surface the ATT alert if the AdMob app has an IDFA message configured and the plist contains `NSUserTrackingUsageDescription`

## Home Feed Placement

- Home feed insertion logic lives in [lib/screens/home/home_screen.dart](/Users/umermalik/beat_that/lib/screens/home/home_screen.dart).
- Ad unit selection lives in [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).
- Native ad rendering lives in [lib/widgets/home_feed_native_ad_card.dart](/Users/umermalik/beat_that/lib/widgets/home_feed_native_ad_card.dart).

Current behavior:

- First ad appears after 4 videos.
- Later ads appear every 8 videos.
- Android uses the small native template.
- iOS uses the medium native template to satisfy the native ad validator for video creatives.

## Home Video Feed Placement

- Full-screen feed screen lives in [lib/screens/home/video_feed/presentation/home_video_feed_screen.dart](/Users/umermalik/beat_that/lib/screens/home/video_feed/presentation/home_video_feed_screen.dart).
- Interstitial ad IDs live in [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).
- This placement uses interstitial ads instead of inserting ad pages into the `PageView`.

Current behavior:

- Interstitials are preloaded for Android and iOS.
- Ads are only eligible after consent allows ad requests.
- The screen counts forward video swipes rather than raw page rebuilds.
- Test cadence is currently every 3 videos to validate the flow quickly.
- Intended release cadence is first interstitial after 8 videos, then every 10 videos after that.

Why this format is used:

- Google recommends interstitials for natural transition points.
- This full-screen feed already treats each page index as a real video with its own controller state.
- Using an interstitial avoids refactoring the `PageView` into mixed video and ad pages.

## Explore Feed Placement

- Explore grid screen lives in [lib/screens/explore/explore_screen.dart](/Users/umermalik/beat_that/lib/screens/explore/explore_screen.dart).
- Explore uses the same grouped grid pattern as Home so ads do not break video index mapping.
- Explore native ad rendering uses [lib/widgets/explore_feed_native_ad_card.dart](/Users/umermalik/beat_that/lib/widgets/explore_feed_native_ad_card.dart), which reuses the shared [lib/widgets/feed_native_ad_card.dart](/Users/umermalik/beat_that/lib/widgets/feed_native_ad_card.dart) implementation.

Current behavior:

- First Explore ad appears after 4 videos.
- Later Explore ads appear every 8 videos.
- Debug and profile builds use Google's native test IDs.
- Production Explore native ad IDs are configured in [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).

## Explore Video Feed Placement

- Full-screen Explore feed screen lives in [lib/screens/explore/video_feed/explore_video_feed_screen.dart](/Users/umermalik/beat_that/lib/screens/explore/video_feed/explore_video_feed_screen.dart).
- Interstitial ad IDs live in [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).
- This placement mirrors the Home full-screen feed by using interstitials at transition points instead of injecting ad pages into the `PageView`.

Current behavior:

- Interstitials are preloaded for Android and iOS.
- Ads are only eligible after consent allows ad requests.
- The screen counts forward video swipes rather than raw page rebuilds.
- Test cadence is currently every 3 videos to validate the flow quickly.
- Intended release cadence is first interstitial after 8 videos, then every 10 videos after that.

## Sport Details Placement

- Sport details screen lives in [lib/screens/sports_hub/sport_details_screen.dart](/Users/umermalik/beat_that/lib/screens/sports_hub/sport_details_screen.dart).
- This placement uses a single native ad inside the list flow rather than an interstitial.
- Sport details native ad rendering uses [lib/widgets/sport_details_native_ad_card.dart](/Users/umermalik/beat_that/lib/widgets/sport_details_native_ad_card.dart), which reuses the shared [lib/widgets/feed_native_ad_card.dart](/Users/umermalik/beat_that/lib/widgets/feed_native_ad_card.dart) implementation.

Current behavior:

- One native ad is shown after the intro copy and before the technique list.
- Debug and profile builds use Google's native test IDs.
- Production Sport Details native ad IDs are configured in [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).
- Android and iOS use the medium native template on this screen so the media area is large enough for video-capable native creatives.

## Release Behavior

- Debug and profile builds use Google's test ad unit IDs.
- Release builds use production ad unit IDs.
- The Home feed ad card collapses entirely unless consent allows ads and a native ad actually loads.
- Debug and profile builds still show a loading or unavailable placeholder to help validate integration.
- The Home video feed interstitial uses the same test-vs-release ID split.
- Temporary testing thresholds should be reset to release cadence before shipping.

## Adding More Ad Placements

When adding another placement:

1. Create Android and iOS ad units in AdMob.
2. Add the new IDs to [lib/constants/ad_mob_ids.dart](/Users/umermalik/beat_that/lib/constants/ad_mob_ids.dart).
3. Gate the new placement with [lib/services/ad_mob_consent_service.dart](/Users/umermalik/beat_that/lib/services/ad_mob_consent_service.dart).
4. Pick the smallest acceptable format that passes native/banner validation on both platforms.
5. Test on emulator/simulator first, then on physical devices configured for test traffic.
6. Keep release builds on production IDs only after the placement is validated.

For full-screen video flows:

1. Prefer interstitials at natural transition points over inserting fake ad pages.
2. Preload the ad ahead of the threshold.
3. Do not block content when an interstitial is unavailable.
4. Keep the trigger logic based on forward progress through content, not rebuild count.

## Validation Checklist

- Android and iOS both launch cleanly.
- Consent form appears when required.
- Privacy choices can be reopened.
- Home feed ad renders on both platforms.
- No empty release-only ad container is shown when an ad is unavailable.
- Home video feed interstitial shows only after the configured threshold and dismisses back into the video flow cleanly.
- Explore feed native slot renders in debug/profile and keeps video tap indexes correct when ads are inserted.
- Explore video feed interstitial shows only after the configured threshold and dismisses back into the video flow cleanly.
- Sport details native ad renders as a single in-list placement without interrupting the upload flow.

## Physical Device QA

- Test on a real Android device and a real iPhone before release.
- Confirm the first app launch shows the consent flow when required.
- Confirm the Settings screen can reopen Privacy choices when UMP requires it.
- Confirm Home feed native ads render and do not leave empty gaps when unavailable.
- Confirm Explore feed native ads render and preserve correct tap-to-video indexing.
- Confirm Sport Details native ad renders without native ad validator warnings.
- Confirm Home video feed interstitial dismisses back into the current video flow cleanly.
- Confirm Explore video feed interstitial dismisses back into the current video flow cleanly.
- Confirm no ad surface blocks core actions when an ad fails to load.
- Keep devices in test mode while performing QA on real ad unit IDs.

## Before Release

- Home video feed interstitials are still on testing cadence: first ad after 3 videos, then every 3 videos.
- Explore video feed interstitials are still on testing cadence: first ad after 3 videos, then every 3 videos.
- Before shipping, reset both full-screen video feed placements to the intended release cadence: first interstitial after 8 videos, then every 10 videos after that.
- If iOS privacy labels in App Store Connect claim tracking, verify the AdMob Privacy and messaging page has an active IDFA message for this app before submitting.
- Add an App Review note telling reviewers that the ATT prompt appears through the AdMob UMP consent flow on first launch.