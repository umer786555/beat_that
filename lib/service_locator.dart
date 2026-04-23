import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/theme_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/permission_service.dart';
import 'package:beat_that/routes/app_router.dart';

/// Service Locator instance for dependency injection
final getIt = GetIt.instance;

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
    getIt.registerSingleton<PreferencesService>(preferencesService);

    // Register ThemeService (depends on PreferencesService)
    getIt.registerSingleton<ThemeService>(
      SharedPreferencesThemeService(
        preferencesService: getIt<PreferencesService>(),
      ),
    );

    // Register AuthService
    getIt.registerSingleton<AuthService>(
      AuthService(),
    );

    // Register AppRouter
    getIt.registerSingleton<AppRouter>(
      AppRouter(),
    );

    // Register PermissionService
    getIt.registerSingleton<PermissionService>(
      PermissionService(),
    );
  } catch (e, stackTrace) {
    debugPrintStack(
      label: 'ERROR: Failed to register services in service locator',
      stackTrace: stackTrace,
    );
    rethrow; // Let caller (main) handle the error
  }
}
