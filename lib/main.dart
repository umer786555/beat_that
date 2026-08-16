import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_that/bloc/follow_counts_cubit.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/theme_service.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/constants/app_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In main.dartßå
  // if (kDebugMode) {
  await Supabase.initialize(
    url: 'https://hsyqamsignfrbsifrkmu.supabase.co',

    anonKey: 'sb_publishable_0fYQfoXXyTq7Oexc54H_-A_lPipG7MW',
  );
  } 
  // else  async {
  //   await Supabase.initialize(
  
  //     url: 'https://eluksmhzledvstyykjyj.supabase.co',
  //     anonKey: 'sb_publishable_q6O-_lmj2hiXyo6K9ZqWvg_bGG5yXmd',
  //   );
  // }

  // Initialize async services
  final preferencesService = await initializeAsyncServices();

  // Register all services with initialized dependencies
  setupServiceLocator(preferencesService);

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
  late final ThemeBloc _themeBloc;
  // Shared above the router so any route can refresh counts after a
  // follow/unfollow action without reaching into ProfileBloc directly.
  late final FollowCountsCubit _followCountsCubit;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    // Get AppRouter from service locator
    _appRouter = locator<AppRouter>();

    // Create ThemeBloc with ThemeService from service locator
    _themeBloc = ThemeBloc(themeService: locator<ThemeService>());
    _themeBloc.add(const LoadThemeEvent());

    // Keep follow counts as shared app state instead of coupling them to the
    // current user's profile screen. This follows the bloc recommendation of
    // lifting shared state to a higher scope.
    _followCountsCubit = FollowCountsCubit();
    _followCountsCubit.refresh();

    // Get AuthService from service locator to listen to auth state changes
    final authService = locator<AuthService>();

    // Listen to authentication state changes from Supabase
    // When auth state changes (login, logout, session expired, etc.),
    // we need to call router.refresh() so GoRouter re-evaluates the redirect logic
    authService.onAuthStateChanged().listen(
      (event) {
        // Debounce refresh calls to prevent rapid consecutive refreshes
        // that could cause redirect loops or excessive rebuild cycles
        final now = DateTime.now();
        if (_lastRefreshTime == null ||
            now.difference(_lastRefreshTime!).inMilliseconds > 500) {
          _lastRefreshTime = now;

          if (authService.isLoggedIn()) {
            _followCountsCubit.refresh();
          } else {
            _followCountsCubit.reset();
          }

          // Trigger GoRouter's redirect logic
          // The top-level redirect in AppRouter will evaluate the new auth state
          // and navigate to the appropriate route (login, home, etc.)
          _appRouter.router.refresh();
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Auth state stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>.value(value: _themeBloc),
        // Available to all routes because follow actions can happen from the
        // home feed, creator profiles, connections lists, and future screens.
        BlocProvider<FollowCountsCubit>.value(value: _followCountsCubit),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        bloc: _themeBloc,
        builder: (context, themeState) {
          // return MaterialApp.router(
          //   title: 'Beat That',
          //   theme: AppThemes.lightTheme,
          //   darkTheme: AppThemes.darkTheme,
          //   themeMode: themeState.themeMode.isDark
          //       ? ThemeMode.dark
          //       : ThemeMode.light,
          //   routerConfig: _appRouter.router,
          // );
          return MaterialApp.router(
            title: 'Beat That',
            theme: AppThemes.lightTheme(),
            darkTheme: AppThemes.darkTheme(),
            themeMode: themeState.themeMode.isDark
                ? ThemeMode.dark
                : ThemeMode.light,
            routerConfig: _appRouter.router,
          );
        },
      ),
    );
  }
}
