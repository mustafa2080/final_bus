@echo off
REM نسخة Windows من سكريبت رفع الفهارس إلى Firebase

echo ========================================
echo تحديث فهارس Firestore
echo ========================================
echo.

echo 1. التحقق من تثبيت Firebase CLI...
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Firebase CLI غير مثبت!
    echo.
    echo يرجى تثبيته باستخدام:
    echo npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)
echo ✅ Firebase CLI مثبت

echo.
echo 2. تسجيل الدخول إلى Firebase...
firebase login
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل تسجيل الدخول
    pause
    exit /b 1
)
echo ✅ تم تسجيل الدخول بنجاح

echo.
echo 3. رفع الفهارس إلى Firebase...
firebase deploy --only firestore:indexes
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل رفع الفهارس
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ تم تحديث الفهارس بنجاح!
echo ========================================
echo.
echo ملاحظة: قد يستغرق بناء الفهارس بضع دقائق
echo يمكنك متابعة التقدم في Firebase Console
echo.
pause
