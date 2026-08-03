import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/animated_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _staggerController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart));
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  // Egyptian mobile number validation
  String? _validateEgyptianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }

    // Normalize phone number
    String cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.startsWith('0020')) {
      cleanPhone = cleanPhone.replaceFirst('0020', '+20');
    } else if (cleanPhone.startsWith('20')) {
      cleanPhone = cleanPhone.replaceFirst('20', '+20');
    } else if (!cleanPhone.startsWith('+20') && !cleanPhone.startsWith('0')) {
      cleanPhone = '0$cleanPhone';
    }

    // Egyptian mobile patterns
    final pattern = RegExp(r'^(\+20|0)(10|11|12|15)[0-9]{8}');
    if (!pattern.hasMatch(cleanPhone)) {
      return '''رقم الهاتف غير صحيح
يجب أن يبدأ بـ: 010, 011, 012, أو 015''';
    }

    // Validate network prefix
    String prefix = cleanPhone.startsWith('+20')
        ? cleanPhone.substring(3, 6)
        : cleanPhone.substring(0, 3);
    const networkNames = {
      '010': 'فودافون',
      '011': 'اتصالات',
      '012': 'أورانج',
      '015': 'WE',
    };

    if (!networkNames.containsKey(prefix)) {
      return '''رقم الهاتف غير صالح لشبكات مصر
الشبكات المدعومة: فودافون، اتصالات، أورانج، WE''';
    }

    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showErrorDialog('يرجى الموافقة على الشروط والأحكام');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      print('🔐 محاولة إنشاء حساب جديد للمستخدم: ${_emailController.text.trim()}');
      
      final UserModel? user = await authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        userType: UserType.parent,
      );

      if (user != null && mounted) {
        print('✅ تم إنشاء الحساب بنجاح، المستخدم: ${user.name}');
        HapticFeedback.vibrate();
        _showSuccessDialog();
      }
    } catch (e) {
      print('❌ خطأ في إنشاء الحساب: $e');
      if (mounted) {
        HapticFeedback.vibrate();
        String errorMessage = e.toString();
        
        // تنظيف رسالة الخطأ
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }
        
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            const Text('خطأ'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[400]),
            const SizedBox(width: 8),
            const Text('تم بنجاح'),
          ],
        ),
        content: const Text('تم إنشاء حسابك بنجاح! يمكنك الآن تسجيل الدخول والوصول إلى حسابك.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to parent home directly since user is now authenticated
              context.go('/parent');
            },
            child: const Text('متابعة إلى الحساب'),
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
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ResponsiveBuilder(
                      constraints: constraints,
                      builder: (context, isMobile, isTablet, isDesktop) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: _getHorizontalPadding(isMobile, isTablet, isDesktop),
                            vertical: isMobile ? 16.0 : 24.0,
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Form(
                                key: _formKey,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).viewInsets.bottom * 0.5,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildResponsiveHeaderSection(isMobile, isTablet, isDesktop),
                                      SizedBox(height: _getSpacing(40, isMobile, isTablet, isDesktop)),
                                      ..._buildStaggeredFormFields(isMobile, isTablet, isDesktop),
                                      SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
                                      _buildTermsCheckbox(isMobile, isTablet, isDesktop),
                                      SizedBox(height: _getSpacing(32, isMobile, isTablet, isDesktop)),
                                      _buildRegisterButton(isMobile, isTablet, isDesktop),
                                      SizedBox(height: _getSpacing(24, isMobile, isTablet, isDesktop)),
                                      _buildLoginLink(isMobile, isTablet, isDesktop),
                                      SizedBox(height: _getSpacing(32, isMobile, isTablet, isDesktop)),
                                    ],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12.0 : 16.0,
            vertical: 12.0,
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: IconButton(
                  iconSize: isNarrow ? 18.0 : 20.0,
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.pop();
                  },
                ),
              ),
              const Spacer(),
              Hero(
                tag: 'app_logo_mini',
                child: Container(
                  padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: isNarrow ? 20.0 : 24.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponsiveHeaderSection(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 28.0 : isTablet ? 32.0 : 36.0;
    final subtitleFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final padding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Colors.white70],
          ).createShader(bounds),
          child: Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
        SizedBox(height: _getSpacing(12, isMobile, isTablet, isDesktop)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            'أدخل بياناتك لإنشاء حساب ولي أمر',
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontFamily: 'Tajawal',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
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

  List<Widget> _buildStaggeredFormFields(bool isMobile, bool isTablet, bool isDesktop) {
    final fields = [
      _buildAnimatedTextField(
        controller: _nameController,
        label: 'الاسم الكامل',
        hint: 'أدخل اسمك الكامل',
        prefixIcon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يرجى إدخال الاسم';
          }
          if (value.trim().split(' ').length < 2) {
            return 'يرجى إدخال الاسم الأول والأخير على الأقل';
          }
          return null;
        },
        delay: 0,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      ),
      SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
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
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(value)) {
            return 'يرجى إدخال بريد إلكتروني صحيح';
          }
          return null;
        },
        delay: 100,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      ),
      SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
      _buildAnimatedTextField(
        controller: _phoneController,
        label: 'رقم الهاتف',
        hint: 'مثال: 01012345678',
        keyboardType: TextInputType.phone,
        prefixIcon: Icons.phone_outlined,
        validator: _validateEgyptianPhone,
        delay: 200,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      ),
      SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
      _buildAnimatedTextField(
        controller: _passwordController,
        label: 'كلمة المرور',
        hint: 'أدخل كلمة مرور قوية',
        obscureText: _obscurePassword,
        prefixIcon: Icons.lock_outline,
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: IconButton(
            key: ValueKey(_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white70,
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
        delay: 300,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      ),
      SizedBox(height: _getSpacing(20, isMobile, isTablet, isDesktop)),
      _buildAnimatedTextField(
        controller: _confirmPasswordController,
        label: 'تأكيد كلمة المرور',
        hint: 'أعد إدخال كلمة المرور',
        obscureText: _obscureConfirmPassword,
        prefixIcon: Icons.lock_outline,
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: IconButton(
            key: ValueKey(_obscureConfirmPassword),
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white70,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يرجى تأكيد كلمة المرور';
          }
          if (value != _passwordController.text) {
            return 'كلمات المرور غير متطابقة';
          }
          return null;
        },
        delay: 400,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      ),
    ];
    return fields;
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
    int delay = 0,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final fontSize = isMobile ? 16.0 : isTablet ? 17.0 : 18.0;
    final padding = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final borderRadius = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animationValue = Curves.easeOut.transform(
          ((_staggerController.value * 1000 - delay) / 600).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
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

  Widget _buildTermsCheckbox(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 14.0 : isTablet ? 16.0 : 16.0;
    final padding = isMobile ? 12.0 : isTablet ? 16.0 : 16.0;
    final checkboxScale = isMobile ? 1.1 : 1.2;
    final borderRadius = isMobile ? 12.0 : 16.0;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animationValue = Curves.easeOut.transform(
          ((_staggerController.value * 1000 - 500) / 300).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: checkboxScale,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _acceptTerms = value ?? false);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: Colors.white,
                      checkColor: const Color(0xFF1E88E5),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8.0 : 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أوافق على الشروط والأحكام',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        SizedBox(height: _getSpacing(4, isMobile, isTablet, isDesktop)),
                        GestureDetector(
                          onTap: _showTermsDialog,
                          child: Text(
                            'اقرأ الشروط والأحكام',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: fontSize - 2,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.8),
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterButton(bool isMobile, bool isTablet, bool isDesktop) {
    final buttonHeight = isMobile ? 50.0 : isTablet ? 56.0 : 60.0;
    final borderRadius = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final fontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final shadowBlur = isMobile ? 12.0 : isTablet ? 15.0 : 18.0;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animationValue = Curves.easeOut.transform(
          ((_staggerController.value * 1000 - 600) / 400).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
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
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _register,
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
                                'جاري إنشاء الحساب...',
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
                                Icons.person_add_rounded,
                                color: const Color(0xFF1E88E5),
                                size: iconSize,
                              ),
                              SizedBox(width: isMobile ? 6.0 : 8.0),
                              Text(
                                'إنشاء الحساب',
                                style: TextStyle(
                                  color: Color(0xFF1E88E5),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink(bool isMobile, bool isTablet, bool isDesktop) {
    final fontSize = isMobile ? 12.0 : isTablet ? 14.0 : 14.0;
    final padding = isMobile ? 12.0 : isTablet ? 16.0 : 16.0;
    final borderRadius = isMobile ? 16.0 : 20.0;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animationValue = Curves.easeOut.transform(
          ((_staggerController.value * 1000 - 700) / 300).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
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
                    'لديك حساب بالفعل؟ ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: fontSize,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.pop();
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
                        'تسجيل الدخول',
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
          ),
        );
      },
    );
  }

  void _showTermsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'الشروط والأحكام',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. استخدام التطبيق',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 8),
              Text(
                'يُستخدم هذا التطبيق لمتابعة الطلاب في الحافلات المدرسية وضمان سلامتهم.',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 16),
              Text(
                '2. خصوصية البيانات',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 8),
              Text(
                'نحن ملتزمون بحماية خصوصية بياناتك الشخصية وعدم مشاركتها مع أطراف ثالثة.',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 16),
              Text(
                '3. المسؤوليات',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 8),
              Text(
                'يتحمل ولي الأمر مسؤولية تحديث بيانات الطالب والتواصل مع إدارة المدرسة.',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'فهمت',
              style: TextStyle(fontFamily: 'Tajawal'),
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