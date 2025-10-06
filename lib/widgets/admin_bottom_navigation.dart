import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';

class AdminBottomNavigation extends StatelessWidget {
  final int currentIndex;
  
  const AdminBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF42A5F5),
            Color(0xFF64B5F6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: _getNavItems(),
        onTap: (index) => _onItemTapped(context, index),
      ),
    );
  }

  List<BottomNavigationBarItem> _getNavItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
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
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        if (currentIndex != 0) context.go('/admin');
        break;
      case 1:
        if (currentIndex != 1) context.go('/admin/students');
        break;
      case 2:
        if (currentIndex != 2) context.go('/admin/buses');
        break;
      case 3:
        if (currentIndex != 3) context.go('/admin/reports');
        break;
      case 4:
        if (currentIndex != 4) context.go('/admin/settings');
        break;
    }
  }


}
