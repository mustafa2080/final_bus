@echo off
chcp 65001 >nul
color 0B

echo.
echo ================================
echo  🔍 فحص إعدادات Backend
echo ================================
echo.

echo 1️⃣ فحص Node.js...
where node >nul 2>nul
if %errorlevel% equ 0 (
    echo    ✅ Node.js مثبت
    node --version
) else (
    echo    ❌ Node.js غير مثبت
    echo    الرجاء التثبيت من: https://nodejs.org
)
echo.

echo 2️⃣ فحص npm...
where npm >nul 2>nul
if %errorlevel% equ 0 (
    echo    ✅ npm موجود
    npm --version
) else (
    echo    ❌ npm غير موجود
)
echo.

echo 3️⃣ فحص serviceAccountKey.json...
if exist "serviceAccountKey.json" (
    echo    ✅ serviceAccountKey.json موجود
) else (
    echo    ❌ serviceAccountKey.json غير موجود!
    echo    يجب الحصول عليه من Firebase Console
)
echo.

echo 4️⃣ فحص node_modules...
if exist "node_modules" (
    echo    ✅ Dependencies مثبتة
) else (
    echo    ⚠️  Dependencies غير مثبتة
    echo    سيتم تثبيتها عند تشغيل start.bat
)
echo.

echo 5️⃣ فحص index.js...
if exist "index.js" (
    echo    ✅ index.js موجود
) else (
    echo    ❌ index.js غير موجود!
)
echo.

echo 6️⃣ فحص .env...
if exist ".env" (
    echo    ✅ .env موجود
) else (
    echo    ⚠️  .env غير موجود (اختياري)
)
echo.

echo ================================
echo  📊 النتيجة
echo ================================
echo.

REM حساب الجاهزية
set /a ready=0
where node >nul 2>nul && set /a ready+=1
if exist "serviceAccountKey.json" set /a ready+=1
if exist "index.js" set /a ready+=1

if %ready% equ 3 (
    color 0A
    echo ✅ كل شيء جاهز!
    echo.
    echo يمكنك الآن تشغيل Backend بـ:
    echo    start.bat
) else (
    color 0E
    echo ⚠️  يوجد مشاكل يجب حلها أولاً
    echo.
    echo راجع الملفات المفقودة أعلاه
)

echo.
pause
