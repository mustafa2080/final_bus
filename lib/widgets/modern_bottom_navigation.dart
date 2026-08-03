import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';

class ModernBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final UserType userType;
  
  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.userType,
  });

  @override
  State<ModernBottomNavigation> createState() => _ModernBottomNavigationState();
}

class _ModernBottomNavigationState extends State<ModernBottomNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _bubbleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bubbleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _bubbleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ModernBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _bubbleController.reset();
      _bubbleController.forward();
    }
  }

  List<NavItem> _getNavItems() {
    switch (widget.userType) {
      case UserType.admin:
        return [
          NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'الرئيسية',
            route: '/admin',
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
          NavItem(
            icon: Icons.school_outlined,
            activeIcon: Icons.school,
            label: 'الطلاب',
            route: '/admin/students',
            gradient: const LinearGradient(
              colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
            ),
          ),
          NavItem(
            icon: Icons.directions_bus_outlined,
            activeIcon: Icons.directions_bus,
            label: 'الحافلات',
            route: '/admin/buses-management',
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9A9E), Color(0xFFFA709A)],
            ),
          ),
          NavItem(
            icon: Icons.assessment_outlined,
            activeIcon: Icons.assessment,
            label: 'التقارير',
            route: '/admin/reports',
            gradient: const LinearGradient(
              colors: [Color(0xFFFECDA3), Color(0xFFFD9853)],
            ),
          ),
          NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'الإعدادات',
            route: '/admin/settings',
            gradient: const LinearGradient(
              colors: [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
            ),
          ),
        ];
      case UserType.supervisor:
        return [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'الرئيسية',
            route: '/supervisor',
            gradient: const LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
            ),
          ),
          NavItem(
            icon: Icons.qr_code_scanner_outlined,
            activeIcon: Icons.qr_code_scanner,
            label: 'المسح',
            route: '/supervisor/qr-scanner',
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
          ),
          NavItem(
            icon: Icons.people_outlined,
            activeIcon: Icons.people,
            label: 'الطلاب',
            route: '/supervisor/students-list',
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
          ),
          NavItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'الإشعارات',
            route: '/supervisor/notifications',
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
          ),
          NavItem(
            icon: Icons.person_outlined,
            activeIcon: Icons.person,
            label: 'الملف الشخصي',
            route: '/supervisor/profile',
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ];
      case UserType.parent:
        return [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'الرئيسية',
            route: '/parent',
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
          NavItem(
            icon: Icons.child_care_outlined,
            activeIcon: Icons.child_care,
            label: 'أطفالي',
            route: '/parent/students',
            gradient: const LinearGradient(
              colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
            ),
          ),
          NavItem(
            icon: Icons.person_off_outlined,
            activeIcon: Icons.person_off,
            label: 'الغياب',
            route: '/parent/location',
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
            ),
          ),
          NavItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'الإشعارات',
            route: '/parent/notifications',
            gradient: const LinearGradient(
              colors: [Color(0xFFFECDA3), Color(0xFFFD9853)],
            ),
          ),
          NavItem(
            icon: Icons.person_outlined,
            activeIcon: Icons.person,
            label: 'حسابي',
            route: '/parent/profile',
            gradient: const LinearGradient(
              colors: [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final navItems = _getNavItems();
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: _getNavHeight(screenHeight),
            margin: EdgeInsets.only(
              left: _getHorizontalMargin(screenWidth),
              right: _getHorizontalMargin(screenWidth),
              bottom: _getBottomMargin(screenHeight),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_getBorderRadius(screenWidth)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_getBorderRadius(screenWidth)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFFAFAFA),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    _buildAnimatedBackground(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: navItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = index == widget.currentIndex;
                        
                        return _buildNavItem(item, isSelected, index, screenWidth, screenHeight);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bubbleAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.03 * _bubbleAnimation.value),
                  Colors.purple.withOpacity(0.02 * _bubbleAnimation.value),
                  Colors.pink.withOpacity(0.03 * _bubbleAnimation.value),
                ],
                stops: const [0.2, 0.6, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    NavItem item,
    bool isSelected,
    int index,
    double screenWidth,
    double screenHeight,
  ) {
    final navItems = _getNavItems();
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(item, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(
            vertical: _getVerticalPadding(screenHeight),
            horizontal: _getHorizontalItemPadding(screenWidth, navItems.length),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background bubble animation
              if (isSelected)
                AnimatedBuilder(
                  animation: _bubbleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _bubbleAnimation.value,
                      child: Container(
                        width: _getSelectionSize(screenWidth),
                        height: _getSelectionSize(screenWidth),
                        decoration: BoxDecoration(
                          gradient: item.gradient,
                          borderRadius: BorderRadius.circular(_getSelectionSize(screenWidth) / 2),
                          boxShadow: [
                            BoxShadow(
                              color: item.gradient.colors.first.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              
              // Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(_getIconPadding(screenWidth)),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: RotationTransition(
                            turns: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        key: ValueKey(isSelected),
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: _getIconSize(screenWidth, isSelected),
                      ),
                    ),
                  ),
                  
                  // Label with fade animation
                  SizedBox(height: _getLabelSpacing(screenHeight)),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontSize: _getLabelFontSize(screenWidth),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Ripple effect
              if (isSelected)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _bubbleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _bubbleAnimation.value * 1.5,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_getSelectionSize(screenWidth) / 2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3 * (1 - _bubbleAnimation.value)),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(NavItem item, int index) {
    if (index == widget.currentIndex) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger animations
    _bubbleController.reset();
    _bubbleController.forward();
    
    // Navigate
    context.go(item.route);
  }

  // Responsive sizing methods
  double _getNavHeight(double screenHeight) {
    if (screenHeight < 600) return 75; // Small screens
    if (screenHeight < 800) return 85; // Medium screens
    return 95; // Large screens
  }

  double _getHorizontalMargin(double screenWidth) {
    if (screenWidth < 400) return 12;
    if (screenWidth < 600) return 16;
    if (screenWidth < 900) return 20;
    return 24;
  }

  double _getBottomMargin(double screenHeight) {
    if (screenHeight < 600) return 12;
    if (screenHeight < 800) return 16;
    return 20;
  }

  double _getBorderRadius(double screenWidth) {
    if (screenWidth < 400) return 20;
    if (screenWidth < 600) return 25;
    return 30;
  }

  double _getVerticalPadding(double screenHeight) {
    if (screenHeight < 600) return 8;
    if (screenHeight < 800) return 10;
    return 12;
  }

  double _getHorizontalItemPadding(double screenWidth, int itemCount) {
    final baseSize = screenWidth / itemCount / 8;
    return baseSize.clamp(4.0, 8.0);
  }

  double _getSelectionSize(double screenWidth) {
    if (screenWidth < 400) return 50;
    if (screenWidth < 600) return 55;
    if (screenWidth < 900) return 60;
    return 65;
  }

  double _getIconPadding(double screenWidth) {
    if (screenWidth < 400) return 4;
    if (screenWidth < 600) return 5;
    return 6;
  }

  double _getIconSize(double screenWidth, bool isSelected) {
    final baseSize = screenWidth < 400 ? 22 : 
                     screenWidth < 600 ? 24 : 
                     screenWidth < 900 ? 26 : 28;
    return isSelected ? (baseSize + 2).toDouble() : baseSize.toDouble();
  }

  double _getLabelSpacing(double screenHeight) {
    if (screenHeight < 600) return 2;
    if (screenHeight < 800) return 3;
    return 4;
  }

  double _getLabelFontSize(double screenWidth) {
    if (screenWidth < 400) return 11;
    if (screenWidth < 600) return 12;
    if (screenWidth < 900) return 13;
    return 14;
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final LinearGradient gradient;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.gradient,
  });
}
