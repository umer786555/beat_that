import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/services/theme_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/dio_upload_service.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/services/video_playback/media_kit_playback_player.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_source_resolver.dart';
import 'package:beat_that/routes/app_router.dart';

/// Service Locator instance for dependency injection
final locator = GetIt.instance;

/// Initialize async services that need to be ready before app runs
/// Returns the initialized PreferencesService for registration in setupServiceLocator
/// This should be called once during app initialization before setupServiceLocator()
///
/// Throws exceptions if initialization fails (e.g., SharedPreferences access issues)
Future<PreferencesService> initializeAsyncServices() async {
  try {
    // Initialize PreferencesService with SharedPreferences
    final preferencesService = PreferencesService();
    await preferencesService.init();

    // Clean up old engagement data (30+ days old) on app startup
    await preferencesService.cleanupOldEngagement();

    return preferencesService;
  } catch (e, stackTrace) {
    debugPrintStack(
      label: 'ERROR: Failed to initialize PreferencesService',
      stackTrace: stackTrace,
    );
    rethrow; // Let caller (main) handle the error
  }
}

/// Set up the service locator (dependency injection)
///
/// Register all application services here (synchronously).
/// This function should be called once during app initialization, after initializeAsyncServices().
///
/// Throws exceptions if service registration fails.
void setupServiceLocator(PreferencesService preferencesService) {
  try {
    // Register PreferencesService (already initialized)
    locator.registerSingleton<PreferencesService>(preferencesService);

    // Register ThemeService (depends on PreferencesService)
    locator.registerSingleton<ThemeService>(
      SharedPreferencesThemeService(
        preferencesService: locator<PreferencesService>(),
      ),
    );

    // Register AuthService
    locator.registerSingleton<AuthService>(
      AuthService(preferencesService: locator<PreferencesService>()),
    );

    locator.registerSingleton<AdMobConsentService>(AdMobConsentService());

    // Register DioUploadService (must be before SupabaseService)
    // SupabaseService depends on DioUploadService in its constructor
    locator.registerSingleton<DioUploadService>(DioUploadService());

    // Register SupabaseService
    // Note: SupabaseService accesses Supabase.instance.client directly,
    // which is initialized in main.dart before this function is called
    locator.registerSingleton<SupabaseService>(SupabaseService());

    // Register AppRouter
    locator.registerSingleton<AppRouter>(AppRouter());

    // Register PermissionService
    locator.registerSingleton<PermissionService>(PermissionService());

    // Register VideoPickerService
    locator.registerSingleton<VideoPickerService>(VideoPickerService());

    // Register HomeFeedService (depends on SupabaseService)
    locator.registerSingleton<HomeFeedService>(HomeFeedService());

    // Register HomeVideoFeedSessionStore for lightweight route handoff
    locator.registerSingleton<HomeVideoFeedSessionStore>(
      HomeVideoFeedSessionStore(),
    );

    locator.registerSingleton<ExploreFeedProgressStore>(
      ExploreFeedProgressStore(),
    );

    locator.registerSingleton<OnboardingService>(
      OnboardingService(preferencesService: locator<PreferencesService>()),
    );

    // A new native player per call; the pool and play-video own their players.
    locator.registerFactory<PlaybackPlayer>(MediaKitPlaybackPlayer.new);

    // Register VideoSourceResolver (depends on SupabaseService)
    locator.registerSingleton<VideoSourceResolver>(
      VideoSourceResolver(supabaseService: locator<SupabaseService>()),
    );

    // App-scoped so the feeds share one capped set of players.
    locator.registerSingleton<VideoPlayerPool>(
      VideoPlayerPool(
        createPlayer: () => locator<PlaybackPlayer>(),
        resolveSource: locator<VideoSourceResolver>().resolve,
      ),
    );

    // Root route observer, so the feeds can pause while a page covers them.
    locator.registerSingleton<RouteObserver<PageRoute<dynamic>>>(
      RouteObserver<PageRoute<dynamic>>(),
    );
  } catch (e, stackTrace) {
    debugPrintStack(
      label: 'ERROR: Failed to register services in service locator',
      stackTrace: stackTrace,
    );
    rethrow; // Let caller (main) handle the error
  }
}
