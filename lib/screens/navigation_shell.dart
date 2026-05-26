import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:persistent_bottom_nav_bar_v2/components/animated_icon_wrapper.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Navigation shell using GoRouter's StatefulShellRoute.
///
/// This widget is used with go_router to provide a persistent bottom navigation bar
/// that integrates seamlessly with the router API.
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return PersistentTabView.router(
      // Define tab configurations with icons and titles
      tabs: [
        // Home Tab
        PersistentRouterTabConfig(
          item: ItemConfig(
            icon: AnimatedIconWrapper(
              duration: const Duration(milliseconds: 900),
              curve: Curves.bounceIn,
              icon: AnimatedIcons.home_menu,
            ),
            title: 'Home',
            activeForegroundColor: AppColors.green,
            inactiveForegroundColor: Colors.grey,
          ),
        ),

        // Explore Tab
        PersistentRouterTabConfig(
          item: ItemConfig(
            icon: AnimatedIconWrapper(
              curve: Curves.bounceIn,
              icon: AnimatedIcons.search_ellipsis,
            ),
            title: 'Explore',
            activeForegroundColor: AppColors.green,
            inactiveForegroundColor: Colors.grey,
          ),
        ),

        // Profile Tab
        PersistentRouterTabConfig(
          item: ItemConfig(
            icon: AnimatedIconWrapper(icon: AnimatedIcons.menu_arrow),
            title: 'Profile',
            activeForegroundColor: AppColors.green,
            inactiveForegroundColor: Colors.grey,
          ),
        ),
      ],

      // Pass the navigation shell from GoRouter
      navigationShell: navigationShell,

      // Trigger haptic feedback when switching tabs
      onTabChanged: (index) {
        HapticFeedback.mediumImpact();
      },

      // Configure the navigation bar appearance with Style1
      navBarBuilder: (navBarConfig) => Style1BottomNavBar(
        navBarConfig: navBarConfig,
        navBarDecoration: NavBarDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.grey.shade800, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
      ),
      gestureNavigationEnabled: true,
      // Background color
      backgroundColor: Colors.white,
    );
  }
}
