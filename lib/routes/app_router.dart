import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/home_screen.dart';
import 'package:beat_that/screens/auth/login_screen.dart';
import 'package:beat_that/screens/auth/signup_screen.dart';

/// Route paths for the application
class AppRoutes {
  // Auth routes
  static const String login = '/login';
  static const String signup = '/signup';

  // App routes
  static const String home = '/home';
}

/// GoRouter configuration for the application
///
/// Implements authentication-based redirect logic following GoRouter best practices:
/// - Top-level redirect for app-wide authentication checks
/// - Returns null to allow navigation, or a location string to redirect
/// - Uses fullPath as the source of truth during route transitions
/// 
/// See: https://pub.dev/packages/go_router
class AppRouter {
  AppRouter();

  /// List of public (authentication) routes that don't require login
  static const List<String> _publicRoutes = [
    AppRoutes.login,
    AppRoutes.signup,
  ];

  GoRouter? _routerInstance;

  /// Get or create the GoRouter instance
  /// 
  /// The router is lazily initialized on first access to ensure that
  /// the service locator is fully set up before the router accesses dependencies.
  GoRouter get router {
    _routerInstance ??= GoRouter(
      // Set to true to enable detailed logging for debugging
      debugLogDiagnostics: true,

      /// Top-level redirect logic for authentication state
      /// 
      /// This is called on every route change before any route-level redirects.
      /// It's the single source of truth for authentication-based navigation decisions.
      /// 
      /// Returns:
      /// - null: Allow navigation to the intended route
      /// - '/path': Redirect to a different route
      redirect: (BuildContext context, GoRouterState state) {
        final authService = getIt<AuthService>();
        final isLoggedIn = authService.isLoggedIn();
        
        // Use fullPath as the source of truth during transitions (name may be null)
        // fullPath corresponds to the route path, not the name
        final currentPath = state.fullPath ?? '';
        
        // Determine if the current route is a public authentication route
        final isPublicRoute = _publicRoutes.any((route) => currentPath.startsWith(route));

        // Rule 1: If not logged in and trying to access a protected route, redirect to login
        if (!isLoggedIn && !isPublicRoute) {
          return AppRoutes.login;
        }

        // Rule 2: If logged in and on an auth route, redirect to home
        if (isLoggedIn && isPublicRoute) {
          return AppRoutes.home;
        }

        // Rule 3: Allow all other navigations
        return null;
      },

      /// Initial location when the app first loads
      /// The redirect logic above will adjust this based on authentication state
      initialLocation: AppRoutes.home,

      /// Define all routes for the application
      /// Using named routes for type-safe navigation with goNamed()
      routes: [
        /// Public authentication routes (require NOT logged in)
        /// Login uses Fade pattern: enter with fade + scale (80% → 100%)
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fade + Scale transition: 80% → 100%
                final scaleTween = Tween(begin: 0.8, end: 1.0);
                final fadeTween = CurveTween(curve: Curves.easeInOutCirc);
                
                return FadeTransition(
                  opacity: fadeTween.animate(animation),
                  child: ScaleTransition(
                    scale: animation.drive(scaleTween),
                    child: child,
                  ),
                );
              },
            );
          },
        ),

        /// Signup uses Fade Through pattern: outgoing fade out, incoming fades in + scales
        GoRoute(
          path: AppRoutes.signup,
          name: 'signup',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const SignupScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fade Through: outgoing fades out, incoming fades in + scales (92% → 100%)
                final scaleTween = Tween(begin: 0.92, end: 1.0);
                final fadeTween = Tween(begin: 0.0, end: 1.0);
                
                return FadeTransition(
                  opacity: fadeTween.animate(animation),
                  child: ScaleTransition(
                    scale: animation.drive(scaleTween),
                    child: child,
                  ),
                );
              },
            );
          },
        ),

        /// Protected routes (require logged in)
        /// Home uses Fade Through with Z-axis hierarchy: shows app structure change
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fade Through Z-axis: fade in + scale to show hierarchy elevation
                final scaleTween = Tween(begin: 0.92, end: 1.0);
                final fadeTween = CurveTween(curve: Curves.easeInOutCirc);
                
                return FadeTransition(
                  opacity: fadeTween.animate(animation),
                  child: ScaleTransition(
                    scale: animation.drive(scaleTween),
                    child: child,
                  ),
                );
              },
            );
          },
        ),
      ],

      /// Error handling for undefined routes
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Page not found: ${state.error}'),
        ),
      ),
    );
    return _routerInstance!;
  }
}
