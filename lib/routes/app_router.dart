import 'dart:convert';

import 'package:beat_that/models/sport.dart';
import 'package:beat_that/models/sport_subcategory.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_route_extra.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_screen.dart';
import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/screens/play_uploaded_video.dart/play_uploaded_video_screen.dart';
import 'package:beat_that/screens/edit_thumbnail/edit_thumbnail_screen.dart';
import 'package:beat_that/screens/home/video_feed/models/home_video_feed_route_extra.dart';
import 'package:beat_that/screens/home/video_feed/presentation/home_video_feed_screen.dart';
import 'package:beat_that/screens/sports_hub/sport_details_screen.dart';
import 'package:beat_that/screens/username_setup/username_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/navigation_shell.dart';
import 'package:beat_that/screens/home/home_screen.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/screens/explore/explore_screen.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_screen.dart';
import 'package:beat_that/screens/profile/profile_screen.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/screens/profile/connections/profile_connections_screen.dart';
import 'package:beat_that/screens/settings/bloc/settings_bloc.dart';
import 'package:beat_that/screens/settings/blocked_users_screen.dart';
import 'package:beat_that/screens/settings/settings_screen.dart';
import 'package:beat_that/screens/creator_profile/creator_profile_screen.dart';
import 'package:beat_that/screens/auth/auth_choice_screen.dart';
import 'package:beat_that/screens/auth/forgot_password_screen.dart';
import 'package:beat_that/screens/auth/login_screen.dart';
import 'package:beat_that/screens/auth/reset_password_screen.dart';
import 'package:beat_that/screens/auth/signup_screen.dart';

/// Extra data for PlayUploadedVideo route
class PlayUploadedVideoExtra {
  final String videoPath;
  final bool shouldShowEditButtons;
  final Sport? sport;
  final String? selectedSubcategory;

  PlayUploadedVideoExtra({
    required this.videoPath,
    required this.shouldShowEditButtons,
    this.sport,
    this.selectedSubcategory,
  });
}

/// Extra data for EditThumbnail route
class EditThumbnailExtra {
  final String videoPath;
  final Duration videoDuration;
  final Sport sport;
  final String? selectedSubcategory;

  EditThumbnailExtra({
    required this.videoPath,
    required this.videoDuration,
    required this.sport,
    this.selectedSubcategory,
  });
}

/// Extra data for SportDetails route
class SportDetailsExtra {
  final Sport sport;

  SportDetailsExtra({required this.sport});
}

class ProfileConnectionsExtra {
  final String connectionType;

  ProfileConnectionsExtra({required this.connectionType});
}

class CreatorProfileExtra {
  final String userId;

  CreatorProfileExtra({required this.userId});
}

/// Custom codec for serializing/deserializing route extras
class _RouteExtraCodec extends Codec<Object?, Object?> {
  const _RouteExtraCodec();

  @override
  Converter<Object?, Object?> get decoder => const _RouteExtraDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _RouteExtraEncoder();
}

class _RouteExtraEncoder extends Converter<Object?, Object?> {
  const _RouteExtraEncoder();

  @override
  Object? convert(Object? input) {
    if (input == null) {
      return null;
    }
    switch (input) {
      case PlayUploadedVideoExtra _:
        return <Object?>[
          'PlayUploadedVideoExtra',
          input.videoPath,
          input.shouldShowEditButtons,
          input.sport?.id,
          input.selectedSubcategory,
        ];
      case EditThumbnailExtra _:
        return <Object?>[
          'EditThumbnailExtra',
          input.videoPath,
          input.videoDuration.inMilliseconds,
          input.sport.id,
          input.selectedSubcategory,
        ];
      case SportDetailsExtra _:
        return <Object?>[
          'SportDetailsExtra',
          input.sport.id,
          jsonEncode(input.sport.subcategories.map((s) => s.toJson()).toList()),
        ];
      case HomeVideoFeedExtra _:
        return <Object?>[
          'HomeVideoFeedExtra',
          input.sessionId,
          input.initialIndex,
        ];
      case ExploreVideoFeedExtra _:
        return <Object?>[
          'ExploreVideoFeedExtra',
          input.videos,
          input.initialIndex,
          input.query,
          input.searchMode.name,
          input.selectedSportId,
          input.nextOffset,
          input.hasMoreContent,
        ];
      case ProfileConnectionsExtra _:
        return <Object?>['ProfileConnectionsExtra', input.connectionType];
      case CreatorProfileExtra _:
        return <Object?>['CreatorProfileExtra', input.userId];
      default:
        throw FormatException('Cannot encode type ${input.runtimeType}');
    }
  }
}

class _RouteExtraDecoder extends Converter<Object?, Object?> {
  const _RouteExtraDecoder();

  @override
  Object? convert(Object? input) {
    if (input == null) {
      return null;
    }
    final inputAsList = input as List<Object?>;
    if (inputAsList[0] == 'PlayUploadedVideoExtra') {
      final sportId = inputAsList[3] as String?;
      final selectedSubcategory = inputAsList[4] as String?;
      return PlayUploadedVideoExtra(
        videoPath: inputAsList[1]! as String,
        shouldShowEditButtons: inputAsList[2]! as bool,
        sport: sportId != null
            ? Sport(
                id: sportId,
                name: sportId,
                displayName: getDisplayNameForSport(sportId),
                icon: getIconForSport(sportId),
                imageAssetPath: getImageAssetPathForSport(sportId),
                subcategories: [],
              )
            : null,
        selectedSubcategory: selectedSubcategory,
      );
    }
    if (inputAsList[0] == 'EditThumbnailExtra') {
      final sportId = inputAsList[3] as String;
      final selectedSubcategory = inputAsList[4] as String?;
      return EditThumbnailExtra(
        videoPath: inputAsList[1]! as String,
        videoDuration: Duration(milliseconds: inputAsList[2]! as int),
        sport: Sport(
          id: sportId,
          name: sportId,
          displayName: getDisplayNameForSport(sportId),
          icon: getIconForSport(sportId),
          imageAssetPath: getImageAssetPathForSport(sportId),
          subcategories: [],
        ),
        selectedSubcategory: selectedSubcategory,
      );
    }
    if (inputAsList[0] == 'SportDetailsExtra') {
      final sportId = inputAsList[1] as String;
      final subcategoriesJson = inputAsList[2] as String;
      final subcategories = (jsonDecode(subcategoriesJson) as List<dynamic>)
          .map(
            (item) => SportSubcategory.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      final sport = Sport(
        id: sportId,
        name: sportId,
        displayName: getDisplayNameForSport(sportId),
        icon: getIconForSport(sportId),
        imageAssetPath: getImageAssetPathForSport(sportId),
        subcategories: subcategories,
      );
      return SportDetailsExtra(sport: sport);
    }
    if (inputAsList[0] == 'HomeVideoFeedExtra') {
      final sessionId = inputAsList[1] as String;
      final initialIndex = inputAsList[2] as int;
      return HomeVideoFeedExtra(
        sessionId: sessionId,
        initialIndex: initialIndex,
      );
    }
    if (inputAsList[0] == 'ExploreVideoFeedExtra') {
      return ExploreVideoFeedExtra(
        videos: List<Map<String, dynamic>>.from(
          (inputAsList[1] as List<dynamic>).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        ),
        initialIndex: inputAsList[2] as int,
        query: inputAsList[3] as String,
        searchMode: ExploreSearchMode.values.byName(inputAsList[4] as String),
        selectedSportId: inputAsList[5] as String?,
        nextOffset: inputAsList[6] as int,
        hasMoreContent: inputAsList[7] as bool,
      );
    }
    if (inputAsList[0] == 'ProfileConnectionsExtra') {
      final connectionType = inputAsList[1] as String;
      return ProfileConnectionsExtra(connectionType: connectionType);
    }
    if (inputAsList[0] == 'CreatorProfileExtra') {
      final userId = inputAsList[1] as String;
      return CreatorProfileExtra(userId: userId);
    }
    throw FormatException('Unable to parse input: $input');
  }
}

/// Route paths for the application
class AppRoutes {
  // Auth routes
  static const String auth = '/auth';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // App routes
  static const String home = '/home';
  static const String homeVideoFeed = '/home/video-feed';
  static const String exploreVideoFeed = '/explore/video-feed';
  static const String profileConnections = '/profile/connections';
  static const String creatorProfile = '/creator-profile';
  static const String playVideo = '/play-video';
  static const String blockedUsers = '/profile/blocked-users';

  // Profile routes
  static const String editUploadedVideo = '/profile/edit-uploaded-video';
  static const String editThumbnail = '/profile/edit-thumbnail';
  static const String settings = '/profile/settings';
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
    AppRoutes.auth,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
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

      /// Custom codec for handling route extras
      /// Converts complex types to/from serializable objects
      extraCodec: const _RouteExtraCodec(),

      /// Top-level redirect logic for authentication state
      ///
      /// This is called on every route change before any route-level redirects.
      /// It's the single source of truth for authentication-based navigation decisions.
      ///
      /// Returns:
      /// - null: Allow navigation to the intended route
      /// - '/path': Redirect to a different route
      redirect: (BuildContext context, GoRouterState state) {
        final authService = locator<AuthService>();
        final isLoggedIn = authService.isLoggedIn();

        // Use fullPath as the source of truth during transitions (name may be null)
        // fullPath corresponds to the route path, not the name
        final currentPath = state.fullPath ?? '';

        // Determine if the current route is a public authentication route
        final isPublicRoute = _publicRoutes.any(
          (route) => currentPath.startsWith(route),
        );

        // Rule 1: If not logged in and trying to access a protected route, redirect to login
        if (!isLoggedIn && !isPublicRoute) {
          return AppRoutes.auth;
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
        GoRoute(
          path: AppRoutes.auth,
          name: 'auth',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey,
              child: const AuthChoiceScreen(),
            );
          },
        ),

        /// Login uses Fade pattern: enter with fade + scale (80% → 100%)
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
        GoRoute(
          path: AppRoutes.forgotPassword,
          name: 'forgot-password',
          pageBuilder: (context, state) {
            final initialEmail = state.uri.queryParameters['email'] ?? '';
            return CustomTransitionPage(
              key: state.pageKey,
              child: ForgotPasswordScreen(initialEmail: initialEmail),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
        GoRoute(
          path: AppRoutes.resetPassword,
          name: 'reset-password',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const ResetPasswordScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    final tween = Tween(begin: begin, end: end);
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return SlideTransition(
                      position: tween.animate(curvedAnimation),
                      child: child,
                    );
                  },
            );
          },
        ),

        /// Username Setup (full-screen, no navigation bar)
        GoRoute(
          path: '/username-setup',
          name: 'username-setup',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey,
              child: const UsernameSetupScreen(),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.homeVideoFeed,
          name: 'home-video-feed',
          pageBuilder: (context, state) {
            final extra = state.extra as HomeVideoFeedExtra;
            return CustomTransitionPage(
              key: state.pageKey,
              child: HomeVideoFeedScreen(
                sessionId: extra.sessionId,
                initialIndex: extra.initialIndex,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.exploreVideoFeed,
          name: 'explore-video-feed',
          pageBuilder: (context, state) {
            final extra = state.extra as ExploreVideoFeedExtra;
            return CustomTransitionPage(
              key: state.pageKey,
              child: ExploreVideoFeedScreen(extra: extra),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.creatorProfile,
          name: 'creator-profile',
          pageBuilder: (context, state) {
            final extra = state.extra as CreatorProfileExtra;
            return CustomTransitionPage(
              key: state.pageKey,
              child: CreatorProfileScreen(userId: extra.userId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    final tween = Tween(begin: begin, end: end);
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return SlideTransition(
                      position: tween.animate(curvedAnimation),
                      child: child,
                    );
                  },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.playVideo,
          name: 'play-video',
          pageBuilder: (context, state) {
            final extra = state.extra as PlayUploadedVideoExtra;
            return CustomTransitionPage(
              key: state.pageKey,
              child: PlayUploadedVideoScreen(
                videoPath: extra.videoPath,
                shouldShowEditButtons: extra.shouldShowEditButtons,
                sport: extra.sport,
                selectedSubcategory: extra.selectedSubcategory,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    final tween = Tween(begin: begin, end: end);
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return SlideTransition(
                      position: tween.animate(curvedAnimation),
                      child: child,
                    );
                  },
            );
          },
        ),

        /// Protected routes (require logged in)
        /// Home navigation shell with persistent bottom navigation bar using StatefulShellRoute
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) =>
                      ProfileBloc()..add(const LoadProfileEvent()),
                ),
              ],
              child: NavigationShell(navigationShell: navigationShell),
            );
          },
          branches: [
            /// Home Tab Branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  name: 'home',
                  pageBuilder: (context, state) {
                    return NoTransitionPage(
                      key: state.pageKey,
                      child: BlocProvider(
                        create: (context) =>
                            HomeBloc()..add(const InitialEvent()),
                        child: const HomeScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            /// Explore Tab Branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  name: 'explore',
                  pageBuilder: (context, state) {
                    return NoTransitionPage(
                      key: state.pageKey,
                      child: const ExploreScreen(),
                    );
                  },
                ),
              ],
            ),

            /// Profile Tab Branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  name: 'profile',
                  pageBuilder: (context, state) {
                    return NoTransitionPage(
                      key: state.pageKey,
                      child: ProfileScreen(),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'settings',
                      name: 'settings',
                      pageBuilder: (context, state) {
                        return CustomTransitionPage(
                          key: state.pageKey,
                          child: BlocProvider(
                            create: (context) => SettingsBloc(),
                            child: const SettingsScreen(),
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                final tween = Tween(begin: begin, end: end);
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                );
                                return SlideTransition(
                                  position: tween.animate(curvedAnimation),
                                  child: child,
                                );
                              },
                        );
                      },
                    ),
                    GoRoute(
                      path: 'blocked-users',
                      name: 'blocked-users',
                      pageBuilder: (context, state) {
                        return CustomTransitionPage(
                          key: state.pageKey,
                          child: const BlockedUsersScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                final tween = Tween(begin: begin, end: end);
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                );
                                return SlideTransition(
                                  position: tween.animate(curvedAnimation),
                                  child: child,
                                );
                              },
                        );
                      },
                    ),

                    /// Edit Uploaded Video Child Route
                    GoRoute(
                      path: 'edit-uploaded-video',
                      name: 'edit-uploaded-video',
                      pageBuilder: (context, state) {
                        final extra = state.extra as PlayUploadedVideoExtra;
                        return CustomTransitionPage(
                          key: state.pageKey,
                          child: PlayUploadedVideoScreen(
                            videoPath: extra.videoPath,
                            shouldShowEditButtons: extra.shouldShowEditButtons,
                            sport: extra.sport,
                            selectedSubcategory: extra.selectedSubcategory,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                final tween = Tween(begin: begin, end: end);
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                );
                                return SlideTransition(
                                  position: tween.animate(curvedAnimation),
                                  child: child,
                                );
                              },
                        );
                      },
                    ),

                    /// Edit Thumbnail Child Route
                    GoRoute(
                      path: 'edit-thumbnail',
                      name: 'edit-thumbnail',
                      pageBuilder: (context, state) {
                        final extra = state.extra as EditThumbnailExtra;
                        return CustomTransitionPage(
                          key: state.pageKey,
                          child: EditThumbnailScreen(
                            videoPath: extra.videoPath,
                            videoDuration: extra.videoDuration,
                            sport: extra.sport,
                            selectedSubcategory: extra.selectedSubcategory,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                final tween = Tween(begin: begin, end: end);
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                );
                                return SlideTransition(
                                  position: tween.animate(curvedAnimation),
                                  child: child,
                                );
                              },
                        );
                      },
                    ),

                    /// Sports Hub Child Route
                    GoRoute(
                      path: 'sports-hub',
                      name: 'sports-hub',
                      pageBuilder: (context, state) {
                        return CustomTransitionPage(
                          key: state.pageKey,
                          child: const SportsHubScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                final tween = Tween(begin: begin, end: end);
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                );
                                return SlideTransition(
                                  position: tween.animate(curvedAnimation),
                                  child: child,
                                );
                              },
                        );
                      },
                      routes: [
                        /// Sport Details Child Route
                        GoRoute(
                          path: 'sport-details',
                          name: 'sport-details',
                          pageBuilder: (context, state) {
                            final sportDetailsExtra =
                                state.extra as SportDetailsExtra;
                            final sport = sportDetailsExtra.sport;
                            return CustomTransitionPage(
                              key: state.pageKey,
                              child: SportDetailsScreen(sport: sport),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.0, 1.0);
                                    const end = Offset.zero;
                                    final tween = Tween(begin: begin, end: end);
                                    final curvedAnimation = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeInOut,
                                    );
                                    return SlideTransition(
                                      position: tween.animate(curvedAnimation),
                                      child: child,
                                    );
                                  },
                            );
                          },
                        ),
                        GoRoute(
                          path: 'connections',
                          name: 'profile-connections',
                          pageBuilder: (context, state) {
                            final extra =
                                state.extra as ProfileConnectionsExtra;
                            return CustomTransitionPage(
                              key: state.pageKey,
                              child: ProfileConnectionsScreen(
                                connectionType: extra.connectionType,
                              ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    final tween = Tween(begin: begin, end: end);
                                    final curvedAnimation = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeInOut,
                                    );
                                    return SlideTransition(
                                      position: tween.animate(curvedAnimation),
                                      child: child,
                                    );
                                  },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],

      /// Error handling for undefined routes
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Error',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: Center(child: Text('Page not found: ${state.error}')),
      ),
    );
    return _routerInstance!;
  }
}
