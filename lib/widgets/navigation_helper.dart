import 'package:flutter/material.dart';
import 'modern_bottom_navigation.dart';

/// Navigation Helper class to manage routes and provide easy integration
class NavigationHelper {
  // Route patterns for different user types
  static const Map<UserType, List<String>> _routePatterns = {
    UserType.admin: [
      '/admin',
      '/admin/students',
      '/admin/buses-management', 
      '/admin/reports',
      '/admin/settings',
    ],
    UserType.supervisor: [
      '/supervisor',
      '/supervisor/scanner',
      '/supervisor/students',
      '/supervisor/notifications',
      '/supervisor/profile',
    ],
    UserType.parent: [
      '/parent',
      '/parent/students',
      '/parent/location',
      '/parent/notifications',
      '/parent/profile',
    ],
  };

  /// Determines the current index based on current route and user type
  static int getCurrentIndex(String currentRoute, UserType userType) {
    final routes = _routePatterns[userType] ?? [];
    
    for (int i = 0; i < routes.length; i++) {
      if (currentRoute.startsWith(routes[i])) {
        return i;
      }
    }
    
    return 0; // Default to first tab
  }

  /// Gets user type from current route
  static UserType? getUserTypeFromRoute(String currentRoute) {
    if (currentRoute.startsWith('/admin')) return UserType.admin;
    if (currentRoute.startsWith('/supervisor')) return UserType.supervisor;
    if (currentRoute.startsWith('/parent')) return UserType.parent;
    return null;
  }

  /// Creates the appropriate bottom navigation for current context
  static Widget createBottomNavigation({
    required String currentRoute,
    UserType? userType,
  }) {
    final detectedUserType = userType ?? getUserTypeFromRoute(currentRoute);
    
    if (detectedUserType == null) {
      return const SizedBox.shrink(); // Don't show nav if can't determine user type
    }
    
    final currentIndex = getCurrentIndex(currentRoute, detectedUserType);
    
    return ModernBottomNavigation(
      currentIndex: currentIndex,
      userType: detectedUserType,
    );
  }

  /// Checks if current route should show bottom navigation
  static bool shouldShowBottomNavigation(String currentRoute) {
    // Don't show on auth screens
    if (currentRoute.contains('/auth/') || 
        currentRoute.contains('/login') || 
        currentRoute.contains('/register') ||
        currentRoute.contains('/forgot-password') ||
        currentRoute == '/') {
      return false;
    }
    
    // Don't show on modal/popup screens
    if (currentRoute.contains('/add-') || 
        currentRoute.contains('/edit-') ||
        currentRoute.contains('/create-') ||
        currentRoute.contains('/scanner') && currentRoute.contains('/qr')) {
      return false;
    }
    
    return true;
  }
}

/// Easy-to-use wrapper widget for screens
class ScreenWithBottomNav extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final UserType? userType;
  final bool showBottomNav;

  const ScreenWithBottomNav({
    super.key,
    required this.child,
    required this.currentRoute,
    this.userType,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNav && 
                          NavigationHelper.shouldShowBottomNavigation(currentRoute)
          ? NavigationHelper.createBottomNavigation(
              currentRoute: currentRoute,
              userType: userType,
            )
          : null,
      extendBody: true,
    );
  }
}

/// Mixin for easy integration in existing screens
mixin BottomNavigationMixin<T extends StatefulWidget> on State<T> {
  String get currentRoute;
  UserType? get userType => null;
  bool get showBottomNav => true;

  Widget buildWithBottomNav(Widget child) {
    return ScreenWithBottomNav(
      currentRoute: currentRoute,
      userType: userType,
      showBottomNav: showBottomNav,
      child: child,
    );
  }
}

/// Route transition animations
class NavigationTransitions {
  static PageRouteBuilder slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder fadeIn(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder scaleIn(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}
