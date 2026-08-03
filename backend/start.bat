@echo off
chcp 65001 >nul
title MyBus Backend Service
color 0A

echo.
echo ================================
echo  🚀 MyBus Backend Service  
echo ================================
echo.

REM التحقق من وجود Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Node.js غير مثبت!
    echo.
    echo الرجاء تثبيت Node.js من: https://nodejs.org
    echo.
    pause
    exit /b 1
)

echo ✅ Node.js version:
node --version
echo.

REM التحقق من وجود npm
where npm >nul 2>nul
if %errorlevel% neq 0 (
    color 0C
    echo ❌ npm غير موجود!
    pause
    exit /b 1
)

REM التحقق من وجود serviceAccountKey.json
if not exist "serviceAccountKey.json" (
    color 0E
    echo.
    echo ⚠️  تحذير: ملف serviceAccountKey.json غير موجود!
    echo.
    echo يجب الحصول عليه من Firebase Console:
    echo 1. اذهب إلى Firebase Console
    echo 2. Project Settings ^> Service Accounts
    echo 3. Generate new private key
    echo 4. احفظ الملف كـ serviceAccountKey.json في هذا المجلد
    echo.
    pause
    exit /b 1
)

REM التحقق من وجود node_modules
if not exist "node_modules" (
    echo.
    echo 📦 تثبيت Dependencies...
    echo.
    call npm install
    if %errorlevel% neq 0 (
        color 0C
        echo.
        echo ❌ فشل تثبيت Dependencies!
        pause
        exit /b 1
    )
    echo.
    echo ✅ تم تثبيت Dependencies بنجاح
    echo.
)

echo.
echo ================================
echo  🔥 بدء تشغيل الخدمة...
echo ================================
echo.
echo 💡 الخدمة ستراقب Firestore وترسل الإشعارات خارج التطبيق
echo 💡 لإيقاف الخدمة: اضغط Ctrl+C
echo.
echo ================================
echo.

REM تشغيل الخدمة
node index.js

REM في حالة توقف الخدمة
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ❌ الخدمة توقفت بخطأ!
    echo.
    pause
)
