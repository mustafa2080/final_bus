import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/persistent_auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/navigation_helper.dart';
import '../../utils/ui_helper.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  bool _isDebugMode() {
    return kDebugMode;
  }

  Widget _buildQuickTestButtons(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 12.0 : isTablet ? 14.0 : 14.0;
    final padding = isMobile ? 12.0 : isTablet ? 16.0 : 16.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.all(padding),
      margin: EdgeInsets.only(top: _getSpacing(16, isMobile, isTablet, isDesktop)),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.yellow.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.developer_mode,
                color: Colors.yellow,
                size: isMobile ? 18.0 : 20.0,
              ),
              SizedBox(width: isMobile ? 6.0 : 8.0),
              Text(
                'وضع المطور - اختبار سريع',
                style: TextStyle(
                  color: Colors.yellow.shade200,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          SizedBox(height: _getSpacing(12, isMobile, isTablet, isDesktop)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTestButton('أدمن', 'admin@test.com', '123456', isMobile, isTablet, isDesktop),
              _buildTestButton('مشرف', 'supervisor@test.com', '123456', isMobile, isTablet, isDesktop),
              _buildTestButton('ولي أمر', 'parent@test.com', '123456', isMobile, isTablet, isDesktop),
            ],
          ),
          SizedBox(height: _getSpacing(8, isMobile, isTablet, isDesktop)),
          Text(
            'ℹ️ هذه الأزرار ظاهرة في وضع التطوير فقط',
            style: TextStyle(
              color: Colors.yellow.shade200,
              fontSize: fontSize - 2,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, String email, String password, bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 11.0 : 12.0;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3.0 : 4.0),
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _emailController.text = email;
            _passwordController.text = password;
            setState(() {
              _rememberMe = false;
            });
            _login();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 6.0 : 8.0, horizontal: 4.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.0 : 12.0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ),
    );
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
  }

  void _startAnimations() {
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final authService = Provider.of<PersistentAuthService>(context, listen: false);

    try {
      print('🔐 محاولة تسجيل الدخول للمستخدم: ${_emailController.text.trim()}');

      final UserModel? user = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (user != null && mounted) {
        print('✅ تم تسجيل الدخول بنجاح، المستخدم: ${user.name} (${user.userType})');
        HapticFeedback.vibrate();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          _navigateBasedOnUserType(user.userType);
        }
      }
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      if (mounted) {
        HapticFeedback.vibrate();
        String errorMessage = e.toString();

        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }
        if (errorMessage.contains('PigeonUserDetails') ||
            errorMessage.contains('List<Object?>')) {
          errorMessage = 'خطأ مؤقت في النظام. يرجى المحاولة مرة أخرى.';
        }

        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      default:
        route = '/';
    }

    print('🚀 التنقل إلى: $route');
    context.go(route);
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text(
              'خطأ في تسجيل الدخول',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'حسناً',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        showChildren: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ResponsiveBuilder(
                constraints: constraints,
                builder: (context, isMobile, isTablet, isDesktop) {
                  final horizontalPadding = _getHorizontalPadding(isMobile, isTablet, isDesktop);
                  final logoSize = isMobile ? 100.0 : isTablet ? 140.0 : 160.0;
                  final titleFontSize = isMobile ? 28.0 : isTablet ? 40.0 : 44.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isMobile ? 16.0 : 24.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: isTablet || isDesktop ? 600 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom * 0.5,
                        ),
                        child: Center(
                          child: IntrinsicHeight(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  SizedBox(height: _getSpacing(40, isMobile, isTablet, isDesktop)),
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildLogoSection(
                                      logoSize,
                                      titleFontSize,
                                      isMobile,
                                      isTablet,
                                      isDesktop,
                                    ),
                                  ),
                                  SizedBox(height: _getSpacing(50, isMobile, isTablet, isDesktop)),
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: SlideTransition(
                                      position: _slideAnimation,
                                      child: _buildFormSection(isMobile, isTablet, isDesktop),
                                    ),
                                  ),
                                  SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: _buildFooterSection(isMobile, isTablet, isDesktop),
                                  ),
                                  SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
                                  if (_isDebugMode())
                                    _buildQuickTestButtons(isMobile, isTablet, isDesktop),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  double _getHorizontalPadding(bool isMobile, bool isTablet, bool isDesktop) {
    if (isMobile) return 20.0;
    if (isTablet) return 80.0;
    return 150.0;
  }

  double _getSpacing(double base, bool isMobile, bool isTablet, bool isDesktop) {
    if (isMobile) return base * 0.8;
    if (isTablet) return base;
    return base * 1.2;
  }

  Widget _buildLogoSection(double logoSize, double titleFontSize, bool isMobile, bool isTablet, bool isDesktop) {
    final subtitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final borderRadius = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;

    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(logoSize * 0.25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: isMobile ? 2.0 : 3.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: isMobile ? 15.0 : 20.0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              size: logoSize * 0.5,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: _getSpacing(24, isMobile, isTablet, isDesktop)),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Colors.white70],
          ).createShader(bounds),
          child: Text(
            'كيدز باص',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
        SizedBox(height: _getSpacing(8, isMobile, isTablet, isDesktop)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 20.0,
            vertical: isMobile ? 6.0 : 8.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(bool isMobile, bool isTablet, bool isDesktop) {
    return Column(
      children: [
        _buildAnimatedTextField(
          controller: _emailController,
          label: 'البريد الإلكتروني',
          hint: 'أدخل بريدك الإلكتروني',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال البريد الإلكتروني';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'يرجى إدخال بريد إلكتروني صحيح';
            }
            return null;
          },
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
        ),
        SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
        _buildAnimatedTextField(
          controller: _passwordController,
          label: 'كلمة المرور',
          hint: 'أدخل كلمة المرور',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: IconButton(
              key: ValueKey(_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.white70,
                size: isMobile ? 20.0 : 22.0,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال كلمة المرور';
            }
            if (value.length < 8) {
              return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
            }
            if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
              return 'كلمة المرور يجب أن تحتوي على أحرف وأرقام';
            }
            return null;
          },
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
        ),
        SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
        _buildRememberMeCheckbox(isMobile, isTablet, isDesktop),
        SizedBox(height: _getSpacing(32, isMobile, isTablet, isDesktop)),
        _buildAnimatedButton(isMobile, isTablet, isDesktop),
        SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
        _buildForgotPasswordLink(isMobile, isTablet, isDesktop),
      ],
    );
  }

  Widget _buildRememberMeCheckbox(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 14.0 : isTablet ? 16.0 : 16.0;
    final borderRadius = isMobile ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _rememberMe = value ?? true);
            },
            activeColor: Colors.white,
            checkColor: const Color(0xFF1E88E5),
            side: BorderSide(
              color: Colors.white.withOpacity(0.6),
              width: 2,
            ),
          ),
          SizedBox(width: isMobile ? 6.0 : 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تذكرني',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Tajawal',
                  ),
                ),
                Text(
                  'سيتم حفظ تسجيل دخولك للمرة القادمة',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: fontSize - 2,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final fontSize = isMobile ? 16.0 : isTablet ? 17.0 : 18.0;
    final padding = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final borderRadius = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: isMobile ? 8.0 : 12.0,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                validator: validator,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Tajawal',
                ),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: fontSize - 2,
                    fontFamily: 'Tajawal',
                  ),
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: fontSize,
                    fontFamily: 'Tajawal',
                  ),
                  prefixIcon: prefixIcon != null
                      ? Padding(
                          padding: EdgeInsets.all(padding / 4),
                          child: Icon(
                            prefixIcon,
                            color: Colors.white.withOpacity(0.8),
                            size: iconSize,
                          ),
                        )
                      : null,
                  suffixIcon: suffixIcon,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: fontSize - 4,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Tajawal',
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedButton(bool isMobile, bool isTablet, bool isDesktop) {
    final buttonHeight = isMobile ? 50.0 : isTablet ? 56.0 : 60.0;
    final borderRadius = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final fontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: _isLoading
            ? LinearGradient(
                colors: [
                  Colors.grey.withOpacity(0.6),
                  Colors.grey.withOpacity(0.4),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: isMobile ? 12.0 : 15.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 8.0 : 12.0),
                      Text(
                        'جاري تسجيل الدخول...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login_rounded,
                        color: const Color(0xFF1E88E5),
                        size: iconSize,
                      ),
                      SizedBox(width: isMobile ? 6.0 : 8.0),
                      Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: const Color(0xFF1E88E5),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 12.0 : isTablet ? 14.0 : 14.0;
    final borderRadius = isMobile ? 16.0 : 20.0;

    return TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        context.push('/forgot-password');
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 20.0,
          vertical: isMobile ? 10.0 : 12.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 16.0,
          vertical: isMobile ? 6.0 : 8.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              color: Colors.white.withOpacity(0.9),
              size: isMobile ? 16.0 : 18.0,
            ),
            SizedBox(width: isMobile ? 6.0 : 8.0),
            Text(
              'نسيت كلمة المرور؟',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterSection(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 12.0 : isTablet ? 14.0 : 14.0;
    final borderRadius = isMobile ? 16.0 : 20.0;
    final padding = isMobile ? 12.0 : isTablet ? 16.0 : 16.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: _getSpacing(16, isMobile, isTablet, isDesktop)),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 16.0),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ليس لديك حساب؟ ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: fontSize,
                    fontFamily: 'Tajawal',
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/register');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10.0 : 12.0,
                      vertical: isMobile ? 3.0 : 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(isMobile ? 10.0 : 12.0),
                    ),
                    child: Text(
                      'إنشاء حساب جديد',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for responsive building
class ResponsiveBuilder extends StatelessWidget {
  final BoxConstraints constraints;
  final Widget Function(BuildContext, bool isMobile, bool isTablet, bool isDesktop) builder;

  const ResponsiveBuilder({
    super.key,
    required this.constraints,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = constraints.maxWidth < 600;
    final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
    final isDesktop = constraints.maxWidth >= 1200;

    return builder(context, isMobile, isTablet, isDesktop);
  }
}
