import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/service_locator.dart';

// It's handy to then extract the Supabase client in a variable for later uses
final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ahrpqdjrnriugjdxqkfy.supabase.co',
    anonKey: 'sb_publishable_uSCOer4EsaTo9eDc-TedqQ_bIGWkULu',
  );

  // Register services with GetIt
  setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// App state for managing authentication and routing
/// 
/// Following GoRouter best practices:
/// - Listens to authentication state changes
/// - Calls router.refresh() to re-evaluate redirect logic when auth state changes
/// - Uses debouncing to prevent excessive route refresh cycles
class _MyAppState extends State<MyApp> {
  late final AppRouter _appRouter;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    // Get AppRouter from service locator
    _appRouter = getIt<AppRouter>();
    
    // Get AuthService from service locator to listen to auth state changes
    final authService = getIt<AuthService>();

    // Listen to authentication state changes from Supabase
    // When auth state changes (login, logout, session expired, etc.),
    // we need to call router.refresh() so GoRouter re-evaluates the redirect logic
    authService.onAuthStateChanged().listen((event) {
      // Debounce refresh calls to prevent rapid consecutive refreshes
      // that could cause redirect loops or excessive rebuild cycles
      final now = DateTime.now();
      if (_lastRefreshTime == null ||
          now.difference(_lastRefreshTime!).inMilliseconds > 500) {
        _lastRefreshTime = now;
        
        // Trigger GoRouter's redirect logic
        // The top-level redirect in AppRouter will evaluate the new auth state
        // and navigate to the appropriate route (login, home, etc.)
        _appRouter.router.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beat That',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _appRouter.router,
    );
  }
}
