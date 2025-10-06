import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../main.dart';
import '../services/persistent_auth_service.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../utils/background_utils.dart';
import '../utils/responsive_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/responsive_text.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthStatus();
  }

  // دالة مساعدة للتنقل الآمن
  void _safeNavigate(String route, {bool replacement = true}) {
    if (!mounted) return;
    
    try {
      if (replacement) {
        context.go(route);
      } else {
        context.push(route);
      }
    } catch (e) {
      debugPrint('GoRouter failed, using Navigator: $e');
      if (replacement) {
        Navigator.pushReplacementNamed(context, route);
      } else {
        Navigator.pushNamed(context, route);
      }
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      print('🔍 Starting auth check...');
      
      // محاولة الحصول على الخدمة بطريقة آمنة
      PersistentAuthService? persistentAuthService;
      try {
        persistentAuthService = context.read<PersistentAuthService>();
      } catch (e) {
        print('❌ Error getting PersistentAuthService: $e');
        print('⚠️ Falling back to direct login navigation');
        _navigateToLogin();
        return;
      }
      
      print('🔍 Initializing persistent auth service...');
      await persistentAuthService.initialize();
      
      print('🔍 Auth service initialized. Checking status...');
      print('   - Is authenticated: ${persistentAuthService.isAuthenticated}');
      print('   - Current user data: ${persistentAuthService.currentUserData?.name}');
      print('   - Current user data type: ${persistentAuthService.currentUserData?.userType}');

      if (persistentAuthService.isAuthenticated &&
          persistentAuthService.currentUserData != null) {
        print('✅ User is authenticated: ${persistentAuthService.currentUserData!.name}');
        _navigateBasedOnUserType(persistentAuthService.currentUserData!.userType);
      } else {
        print('⚠️ User is not authenticated, navigating to login');
        _navigateToLogin();
      }
    } catch (e, stackTrace) {
      print('❌ Error checking auth status: $e');
      print('❌ Stack trace: $stackTrace');
      // في حالة الخطأ، انتقل إلى شاشة تسجيل الدخول
      _navigateToLogin();
    }
  }

  void _navigateBasedOnUserType(UserType userType) {
    String route;
    switch (userType) {
      case UserType.parent:
        route = '/parent';
        break;
      case UserType.supervisor:
        route = '/supervisor';
        break;
      case UserType.admin:
        route = '/admin';
        break;
    }
    
    _safeNavigate(route);
  }

  void _navigateToLogin() {
    _safeNavigate('/login');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ======== Responsive Helpers =========

  double _getResponsiveSize(double baseSize) {
    return ResponsiveHelper.getResponsiveSize(context, baseSize);
  }

  EdgeInsets _getPadding(double basePadding) {
    return ResponsiveHelper.getPadding(context, basePadding: basePadding);
  }

  TextStyle _getResponsiveTextStyle(double baseSize, {FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontSize: _getResponsiveSize(baseSize),
      fontWeight: weight,
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(2, 2),
          blurRadius: 4,
          color: Colors.black.withOpacity(0.4),
        ),
        Shadow(
          offset: Offset(-1, -1),
          blurRadius: 2,
          color: Colors.white.withOpacity(0.3),
        ),
      ],
    );
  }

  // ======== UI Components =========

  Widget _buildBusIllustration() {
    final double busWidth = ResponsiveHelper.isSmallScreen(context) ? 260 : 320;
    final double busHeight = ResponsiveHelper.isSmallScreen(context) ? 180 : 220;

    return SizedBox(
      width: busWidth,
      height: busHeight,
      child: Stack(
        children: [
          // Bus Body
          Positioned(
            left: busWidth * 0.06,
            top: busHeight * 0.22,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 2 * sin(_animationController.value * 2 * pi)),
                  child: Container(
                    width: busWidth * 0.81,
                    height: busHeight * 0.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFA500),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bus Front
          Positioned(
            left: busWidth * 0.75,
            top: busHeight * 0.23,
            child: Container(
              width: busWidth * 0.09,
              height: busHeight * 0.36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),

          // Bus Windows
          _buildBusWindow(busWidth * 0.14, busHeight * 0.25, 0),
          _buildBusWindow(busWidth * 0.26, busHeight * 0.25, 1),
          _buildBusWindow(busWidth * 0.39, busHeight * 0.25, 2),
          _buildBusWindow(busWidth * 0.52, busHeight * 0.25, 3),
          _buildBusWindow(busWidth * 0.64, busHeight * 0.25, 4),
          _buildBusWindow(busWidth * 0.77, busHeight * 0.25, 5),

          // Waving Kids
          _buildWavingKid(busWidth * 0.3, busHeight * 0.2, 1),
          _buildWavingKid(busWidth * 0.42, busHeight * 0.2, 2),
          _buildWavingKid(busWidth * 0.55, busHeight * 0.2, 3),
          _buildWavingKid(busWidth * 0.67, busHeight * 0.2, 4),

          // Wheels
          _buildWheel(busWidth * 0.16, busHeight * 0.6),
          _buildWheel(busWidth * 0.63, busHeight * 0.6),

          // Door
          Positioned(
            left: busWidth * 0.11,
            top: busHeight * 0.44,
            child: Container(
              width: busWidth * 0.08,
              height: busHeight * 0.23,
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),

          // Headlight
          Positioned(
            left: busWidth * 0.77,
            top: busHeight * 0.32,
            child: Container(
              width: busWidth * 0.05,
              height: busWidth * 0.05,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withAlpha(153),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Text Label
          Positioned(
            left: busWidth * 0.28,
            top: busHeight * 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'باص المدرسة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Floating Icons
          _buildFloatingIcon(Icons.favorite, Colors.pink, busWidth * 0.03, busHeight * 0.09, 0.8),
          _buildFloatingIcon(Icons.star, Colors.yellow, busWidth * 0.91, busHeight * 0.14, 1.2),
          _buildFloatingIcon(Icons.favorite, Colors.red, busWidth * 0.05, busHeight * 0.82, 1.0),
          _buildFloatingIcon(Icons.star, Colors.orange, busWidth * 0.94, busHeight * 0.73, 0.9),
          _buildFloatingIcon(Icons.emoji_emotions, Colors.green, busWidth * 0.02, busHeight * 0.45, 1.1),
          _buildFloatingIcon(Icons.child_friendly, Colors.blue, busWidth * 0.92, busHeight * 0.41, 0.7),
          _buildFloatingIcon(Icons.school, Colors.purple, busWidth * 0.88, busHeight * 0.91, 0.8),
          _buildFloatingIcon(Icons.celebration, Colors.cyan, busWidth * 0.08, busHeight * 0.27, 0.9),

          // Balloons
          _buildBalloon(0, busHeight * 0.05, Colors.red),
          _buildBalloon(busWidth * 0.97, busHeight * 0.07, Colors.blue),
          _buildBalloon(0, busHeight * 0.85, Colors.green),
          _buildBalloon(busWidth * 0.95, busHeight * 0.84, Colors.yellow),
        ],
      ),
    );
  }

  Widget _buildBusWindow(double left, double top, int kidIndex) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: _getResponsiveSize(30),
        height: _getResponsiveSize(25),
        decoration: BoxDecoration(
          color: const Color(0xFF87CEEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: kidIndex == 0
            ? const Icon(Icons.person, size: 16, color: Color(0xFF2D3748))
            : _buildKidInWindow(kidIndex),
      ),
    );
  }

  Widget _buildKidInWindow(int kidIndex) {
    final kidData = [
      {'color': Colors.brown, 'icon': Icons.boy, 'name': 'أحمد'},
      {'color': Colors.pink, 'icon': Icons.girl, 'name': 'فاطمة'},
      {'color': Colors.purple, 'icon': Icons.child_care, 'name': 'محمد'},
      {'color': Colors.green, 'icon': Icons.face, 'name': 'نور'},
      {'color': Colors.blue, 'icon': Icons.child_friendly, 'name': 'سارة'},
      {'color': Colors.orange, 'icon': Icons.sentiment_very_satisfied, 'name': 'علي'},
    ];

    final kid = kidData[kidIndex % kidData.length];

    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (0.2 * sin(_animationController.value * 4 * pi + kidIndex)),
            child: Container(
              width: _getResponsiveSize(16),
              height: _getResponsiveSize(16),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    (kid['color'] as Color).withOpacity(0.9),
                    (kid['color'] as Color),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (kid['color'] as Color).withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                kid['icon'] as IconData,
                size: _getResponsiveSize(10),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWavingKid(double left, double top, int kidIndex) {
    final kidColors = [Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.orange];
    final kidColor = kidColors[kidIndex % kidColors.length];

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: 0.3 * sin(_animationController.value * 6 * pi + kidIndex),
            child: Container(
              width: _getResponsiveSize(8),
              height: _getResponsiveSize(12),
              decoration: BoxDecoration(
                color: kidColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: kidColor.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.waving_hand,
                size: _getResponsiveSize(6),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWheel(double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animationController.value * 4 * 3.14159,
            child: Container(
              width: _getResponsiveSize(25),
              height: _getResponsiveSize(25),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(76),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: _getResponsiveSize(10),
                  height: _getResponsiveSize(10),
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: _getResponsiveSize(4),
                    height: _getResponsiveSize(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, Color color, double left, double top, double scale) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              10 * sin(_animationController.value * 2 * pi),
              5 * cos(_animationController.value * 3 * pi),
            ),
            child: Transform.scale(
              scale: scale + (0.3 * sin(_animationController.value * 4 * pi)),
              child: Transform.rotate(
                angle: _animationController.value * 2 * pi,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color.withOpacity(0.9),
                    size: _getResponsiveSize(18),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalloon(double left, double top, Color color) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              5 * sin(_animationController.value * 2 * pi),
              -10 * _animationController.value + 10 * sin(_animationController.value * 4 * pi),
            ),
            child: Column(
              children: [
                Container(
                  width: _getResponsiveSize(12),
                  height: _getResponsiveSize(16),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: _getResponsiveSize(1),
                  height: _getResponsiveSize(15),
                  color: Colors.grey[600],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedLoadingAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: _getResponsiveSize(100),
          height: _getResponsiveSize(100),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        SizedBox(
          width: _getResponsiveSize(80),
          height: _getResponsiveSize(80),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              BackgroundUtils.busYellow.withOpacity(0.8),
            ),
            strokeWidth: 4,
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
        SizedBox(
          width: _getResponsiveSize(60),
          height: _getResponsiveSize(60),
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
          ),
        ),
        SizedBox(
          width: _getResponsiveSize(40),
          height: _getResponsiveSize(40),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              BackgroundUtils.schoolBlue,
            ),
            strokeWidth: 2,
          ),
        ),
        Container(
          width: _getResponsiveSize(30),
          height: _getResponsiveSize(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.9),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus,
            size: _getResponsiveSize(18),
            color: BackgroundUtils.busYellow,
          ),
        ),
        ...List.generate(8, (index) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final angle = (index * 45.0) + (_animationController.value * 360);
              final radians = angle * (pi / 180);
              final radius = _getResponsiveSize(50.0);

              return Positioned(
                left: radius * cos(radians),
                top: radius * sin(radians),
                child: Container(
                  width: _getResponsiveSize(6),
                  height: _getResponsiveSize(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.3 + (0.7 * ((index + _animationController.value * 8) % 8) / 8),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = _getResponsiveSize(20);
    final double verticalSpacing = _getResponsiveSize(30);

    return Directionality(
      textDirection: TextDirection.rtl, // دعم اللغة العربية
      child: Scaffold(
        body: Container(
          color: Colors.transparent,
          child: AnimatedBackground(
            showChildren: true,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Top Section
                              Padding(
                                padding: EdgeInsets.only(
                                  left: horizontalPadding,
                                  right: horizontalPadding,
                                  top: MediaQuery.of(context).padding.top + verticalSpacing * 0.5,
                                  bottom: verticalSpacing * 0.3,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(_slideAnimation.value, 0),
                                      child: _buildBusIllustration(),
                                    ),
                                    const SizedBox(height: 12),

                                    // App Name
                                    AnimatedBuilder(
                                      animation: _animationController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: 0.8 + (_scaleAnimation.value * 0.2),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: _getResponsiveSize(20),
                                              vertical: _getResponsiveSize(10),
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withOpacity(0.2),
                                                  Colors.white.withOpacity(0.1),
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              'كيدز باص',
                                              style: TextStyle(
                                                fontSize: _getResponsiveSize(52),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: _getResponsiveSize(6),
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(4, 4),
                                                    blurRadius: 8,
                                                    color: Colors.black54,
                                                  ),
                                                  Shadow(
                                                    offset: Offset(-2, -2),
                                                    blurRadius: 4,
                                                    color: Colors.white38,
                                                  ),
                                                  Shadow(
                                                    offset: Offset(0, 0),
                                                    blurRadius: 20,
                                                    color: Colors.yellow,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Subtitle
                                    AnimatedBuilder(
                                      animation: _fadeAnimation,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _fadeAnimation.value,
                                          child: Transform.translate(
                                            offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                                            child: Container(
                                              margin: EdgeInsets.symmetric(horizontal: 20.0),
                                              padding: EdgeInsets.symmetric(
                                              horizontal: 28.0,
                                              vertical: 16.0,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(0.25),
                                                    Colors.white.withOpacity(0.15),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(30),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.4),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.white.withOpacity(0.1),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, -2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    'تتبع آمن وسهل لرحلة طفلك المدرسية',
                                                    style: _getResponsiveTextStyle(20, weight: FontWeight.w700),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.security,
                                                        color: Colors.white.withOpacity(0.9),
                                                        size: _getResponsiveSize(16),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'أمان • سهولة • راحة البال',
                                                        style: TextStyle(
                                                          fontSize: _getResponsiveSize(14),
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.favorite,
                                                        color: Colors.white.withOpacity(0.9),
                                                        size: _getResponsiveSize(16),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Loading Section
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 20.0,
                                  right: 20.0,
                                  top: verticalSpacing * 0.5,
                                  bottom: MediaQuery.of(context).padding.bottom + verticalSpacing,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _animationController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: 1.0 + (0.1 * _animationController.value),
                                          child: _buildEnhancedLoadingAnimation(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 25),
                                    AnimatedBuilder(
                                      animation: _fadeAnimation,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _fadeAnimation.value,
                                          child: Column(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                horizontal: 20.0,
                                                vertical: 8.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  'جاري التحميل...',
                                                  style: _getResponsiveTextStyle(18, weight: FontWeight.w600),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'نحضر لك تجربة رائعة...',
                                                style: TextStyle(
                                                  fontSize: _getResponsiveSize(14),
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}