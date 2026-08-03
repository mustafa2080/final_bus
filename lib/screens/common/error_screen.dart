import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/responsive_helper.dart';

/// شاشة الخطأ
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خطأ'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: ResponsiveHelper.getPadding(context,
            mobilePadding: const EdgeInsets.all(16),
            tabletPadding: const EdgeInsets.all(24),
            desktopPadding: const EdgeInsets.all(32)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: ResponsiveHelper.getIconSize(context,
                  mobileSize: 52, tabletSize: 64, desktopSize: 72),
                color: Colors.red,
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context,
                mobileSpacing: 12, tabletSpacing: 16, desktopSpacing: 20)),
              Text(
                'الصفحة غير موجودة',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold),
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context,
                mobileSpacing: 6, tabletSpacing: 8, desktopSpacing: 10)),
              Text(
                'عذراً، لا يمكن العثور على الصفحة المطلوبة',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context,
                mobileSpacing: 20, tabletSpacing: 24, desktopSpacing: 28)),
              SizedBox(
                height: ResponsiveHelper.getButtonHeight(context,
                  mobileHeight: 44, tabletHeight: 48, desktopHeight: 52),
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('العودة للرئيسية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
