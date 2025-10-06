import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';

class ClassicBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final UserType userType;
  
  const ClassicBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.userType,
  });

  List<BottomNavigationBarItem> _getNavItems() {
    switch (userType) {
      case UserType.admin:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'الطلاب',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_outlined),
            activeIcon: Icon(Icons.directions_bus),
            label: 'الحافلات',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'التقارير',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ];
      case UserType.supervisor:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'المسح',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'الطلاب',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ];
      case UserType.parent:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.child_care_outlined),
            activeIcon: Icon(Icons.child_care),
            label: 'أطفالي',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: 'الموقع',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ];
    }
  }

  List<String> _getRoutes() {
    switch (userType) {
      case UserType.admin:
        return [
          '/admin',
          '/admin/students',
          '/admin/buses-management',
          '/admin/reports',
          '/admin/settings',
        ];
      case UserType.supervisor:
        return [
          '/supervisor',
          '/supervisor/qr-scanner',
          '/supervisor/students-list',
          '/supervisor/notifications',
          '/supervisor/profile',
        ];
      case UserType.parent:
        return [
          '/parent',
          '/parent/students',
          '/parent/location',
          '/parent/notifications',
          '/parent/profile',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _getRoutes();
    final navItems = _getNavItems();
    
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1E88E5),
      unselectedItemColor: Colors.grey[600],
      selectedFontSize: 12,
      unselectedFontSize: 11,
      elevation: 8,
      onTap: (index) {
        if (index != currentIndex && index < routes.length) {
          context.go(routes[index]);
        }
      },
      items: navItems,
    );
  }
}
