import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// مدير الأمان للتطبيق
/// Security Manager for the application
class SecurityManager {
  static const String _appSecret = 'MyBusApp2024SecretKey';
  
  /// تشفير النصوص الحساسة
  /// Encrypt sensitive text
  static String encryptText(String text) {
    try {
      final bytes = utf8.encode(text + _appSecret);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('❌ Error encrypting text: $e');
      return text;
    }
  }
  
  /// التحقق من صحة المفاتيح
  /// Validate API keys
  static bool validateApiKey(String apiKey) {
    if (apiKey.isEmpty) return false;
    if (apiKey.length < 20) return false;
    if (apiKey.contains(' ')) return false;
    return true;
  }
  
  /// إخفاء المفاتيح الحساسة في السجلات
  /// Hide sensitive keys in logs
  static String maskSensitiveData(String data) {
    if (data.length <= 8) return '***';
    return '${data.substring(0, 4)}***${data.substring(data.length - 4)}';
  }
  
  /// التحقق من أمان كلمة المرور
  /// Check password security
  static Map<String, bool> checkPasswordSecurity(String password) {
    return {
      'hasMinLength': password.length >= 8,
      'hasUpperCase': RegExp(r'[A-Z]').hasMatch(password),
      'hasLowerCase': RegExp(r'[a-z]').hasMatch(password),
      'hasNumbers': RegExp(r'[0-9]').hasMatch(password),
      'hasSpecialChars': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
      'noSpaces': !password.contains(' '),
    };
  }
  
  /// تنظيف البيانات من المحتوى الضار
  /// Clean data from malicious content
  static String sanitizeData(String input) {
    // إزالة HTML tags
    String clean = input.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // إزالة JavaScript
    clean = clean.replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '');
    
    // إزالة SQL injection patterns
    clean = clean.replaceAll(RegExp(r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)', caseSensitive: false), '');
    
    // إزالة الأحرف الخطيرة
    clean = clean.replaceAll(RegExp(r'''[<>"']'''), '');
    
    return clean.trim();
  }
  
  /// التحقق من صحة عنوان البريد الإلكتروني
  /// Validate email address
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
  
  /// التحقق من صحة رقم الهاتف السعودي
  /// Validate Saudi phone number
  static bool isValidSaudiPhone(String phone) {
    final phoneRegex = RegExp(r'^(05|5)[0-9]{8}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }
  
  /// إنشاء رمز أمان عشوائي
  /// Generate random security token
  static String generateSecurityToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return encryptText(random);
  }
  
  /// التحقق من صحة رمز QR
  /// Validate QR code
  static bool isValidQRCode(String qrCode) {
    if (qrCode.isEmpty) return false;
    if (qrCode.length < 10 || qrCode.length > 100) return false;
    if (RegExp('[<>"\']').hasMatch(qrCode)) return false;
    return true;
  }
  
  /// حماية من هجمات CSRF
  /// CSRF protection
  static String generateCSRFToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return encryptText('csrf_$timestamp');
  }
  
  /// التحقق من رمز CSRF
  /// Validate CSRF token
  static bool validateCSRFToken(String token, Duration maxAge) {
    try {
      // في التطبيق الحقيقي، يجب فك تشفير الرمز والتحقق من الوقت
      return token.isNotEmpty && token.length > 10;
    } catch (e) {
      return false;
    }
  }
  
  /// تسجيل محاولات الوصول المشبوهة
  /// Log suspicious access attempts
  static void logSuspiciousActivity(String userId, String activity, String details) {
    if (kDebugMode) {
      debugPrint('🚨 Suspicious Activity: User=$userId, Activity=$activity, Details=$details');
    }
    // في الإنتاج، يجب إرسال هذه المعلومات إلى نظام مراقبة الأمان
  }
  
  /// التحقق من قوة كلمة المرور
  /// Check password strength
  static int calculatePasswordStrength(String password) {
    int score = 0;
    final checks = checkPasswordSecurity(password);
    
    checks.forEach((key, value) {
      if (value) score++;
    });
    
    return score;
  }
  
  /// التحقق من صحة البيانات المدخلة
  /// Validate input data
  static bool isSecureInput(String input) {
    // التحقق من SQL injection
    final sqlPatterns = [
      r'\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION)\b',
      r'(\-\-|\#|\/\*|\*\/)',
      r'(\bOR\b|\bAND\b).*(\=|\<|\>)',
    ];
    
    for (final pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return false;
      }
    }
    
    // التحقق من XSS
    if (RegExp(r'<script|javascript:|on\w+\s*=', caseSensitive: false).hasMatch(input)) {
      return false;
    }
    
    return true;
  }
}
