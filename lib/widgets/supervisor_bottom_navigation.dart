import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';

class SupervisorBottomNavigation extends StatelessWidget {
  final int currentIndex;
  
  const SupervisorBottomNavigation({
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
        icon: Icon(Icons.person_off_outlined),
        activeIcon: Icon(Icons.person_off),
        label: 'الغياب',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outlined),
        activeIcon: Icon(Icons.person),
        label: 'الملف الشخصي',
      ),
    ];
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        if (currentIndex != 0) context.go('/supervisor');
        break;
      case 1:
        if (currentIndex != 1) context.go('/supervisor/qr-scanner');
        break;
      case 2:
        if (currentIndex != 2) context.go('/supervisor/students-list');
        break;
      case 3:
        if (currentIndex != 3) context.go('/supervisor/absence-management');
        break;
      case 4:
        if (currentIndex != 4) context.go('/supervisor/profile');
        break;
    }
  }
}