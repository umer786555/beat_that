import 'package:get_it/get_it.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/routes/app_router.dart';

/// Service Locator instance for dependency injection
final getIt = GetIt.instance;

/// Set up the service locator (dependency injection)
/// 
/// Register all application services here.
/// This function should be called once during app initialization.
void setupServiceLocator() {
  // Register AuthService as a singleton first (other services may depend on it)
  getIt.registerSingleton<AuthService>(
    AuthService(),
  );

  // Register AppRouter as a singleton (it depends on AuthService)
  getIt.registerSingleton<AppRouter>(
    AppRouter(),
  );
}
