import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/animated_background.dart';
import '../../utils/responsive_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال البريد الإلكتروني: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        showChildren: true,
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: ResponsiveHelper.getPadding(context,
                  mobilePadding: const EdgeInsets.all(12.0),
                  tabletPadding: const EdgeInsets.all(16.0),
                  desktopPadding: const EdgeInsets.all(20.0),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'نسيت كلمة المرور',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(context,
                          mobile: 18, tablet: 20, desktop: 22),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: ResponsiveHelper.getPadding(context,
                    mobilePadding: const EdgeInsets.all(16),
                    tabletPadding: const EdgeInsets.all(24),
                    desktopPadding: const EdgeInsets.all(32),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveHelper.getMaxContentWidth(context) == double.infinity
                            ? double.infinity
                            : 500,
                      ),
                      child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: ResponsiveHelper.getSpacing(context,
                          mobileSpacing: 24, tabletSpacing: 32, desktopSpacing: 40)),
                        // Header Icon
                        Container(
                          alignment: Alignment.center,
                          child: Container(
                            padding: ResponsiveHelper.getPadding(context,
                              mobilePadding: const EdgeInsets.all(16),
                              tabletPadding: const EdgeInsets.all(20),
                              desktopPadding: const EdgeInsets.all(24),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              size: ResponsiveHelper.getIconSize(context,
                                mobileSize: 48, tabletSize: 60, desktopSize: 68),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context,
                          mobileSpacing: 24, tabletSpacing: 32, desktopSpacing: 36)),
                        // Title
                        Text(
                          'إعادة تعيين كلمة المرور',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 22, tablet: 28, desktop: 32),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 4,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context,
                          mobileSpacing: 12, tabletSpacing: 16, desktopSpacing: 18)),
                        // Description
                        Text(
                          _emailSent
                              ? 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني. يرجى فحص صندوق الوارد والبريد المهمل.'
                              : 'أدخل عنوان بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 14, tablet: 16, desktop: 17),
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context,
                          mobileSpacing: 28, tabletSpacing: 40, desktopSpacing: 44)),
                        if (!_emailSent) ...[
                          // Email Field
                          CustomTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال البريد الإلكتروني';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'يرجى إدخال بريد إلكتروني صحيح';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: ResponsiveHelper.getSpacing(context,
                            mobileSpacing: 24, tabletSpacing: 32, desktopSpacing: 36)),
                          // Send Reset Email Button
                          SizedBox(
                            height: ResponsiveHelper.getButtonHeight(context,
                              mobileHeight: 48, tabletHeight: 56, desktopHeight: 60),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendPasswordResetEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )

                          : const Text(
                                      'إرسال رابط إعادة التعيين',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          // Success State
                          Container(
                            padding: ResponsiveHelper.getPadding(context,
                              mobilePadding: const EdgeInsets.all(16),
                              tabletPadding: const EdgeInsets.all(20),
                              desktopPadding: const EdgeInsets.all(24)),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.mark_email_read,
                                  size: ResponsiveHelper.getIconSize(context,
                                    mobileSize: 40, tabletSize: 48, desktopSize: 52),
                                  color: Colors.green[600],
                                ),
                                SizedBox(height: ResponsiveHelper.getSpacing(context,
                                  mobileSpacing: 12, tabletSpacing: 16, desktopSpacing: 18)),
                                Text(
                                  'تم الإرسال بنجاح!',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getFontSize(context,
                                      mobile: 16, tablet: 18, desktop: 20),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.getSpacing(context,
                                  mobileSpacing: 6, tabletSpacing: 8, desktopSpacing: 10)),
                                Text(
                                  'تحقق من بريدك الإلكتروني واتبع التعليمات لإعادة تعيين كلمة المرور',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getFontSize(context,
                                      mobile: 13, tablet: 14, desktop: 15),
                                    color: Colors.green[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Resend Button
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _emailSent = false;
                              });
                            },
                            child: const Text(
                              'إرسال مرة أخرى',
                              style: TextStyle(
                                color: Color(0xFF1E88E5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Back to Login
                        TextButton(
                          onPressed: () {
                            context.pop();
                          },
                          child: const Text(
                            'العودة لتسجيل الدخول',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Help Section
                        Container(
                          padding: ResponsiveHelper.getPadding(context,
                            mobilePadding: const EdgeInsets.all(12),
                            tabletPadding: const EdgeInsets.all(16),
                            desktopPadding: const EdgeInsets.all(20)),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: Colors.blue[600],
                                size: ResponsiveHelper.getIconSize(context,
                                  mobileSize: 20, tabletSize: 24, desktopSize: 26),
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context,
                                mobileSpacing: 6, tabletSpacing: 8, desktopSpacing: 10)),
                              Text(
                                'تحتاج مساعدة؟',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(context,
                                    mobile: 14, tablet: 16, desktop: 17),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context,
                                mobileSpacing: 3, tabletSpacing: 4, desktopSpacing: 5)),
                              Text(
                                'إذا لم تتلق البريد الإلكتروني، تحقق من مجلد البريد المهمل أو تواصل مع الإدارة',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(context,
                                    mobile: 13, tablet: 14, desktop: 15),
                                  color: Colors.blue[700],
                                ),
                                textAlign: TextAlign.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}