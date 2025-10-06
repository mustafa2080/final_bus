@echo off
echo ====================================
echo    تنظيف ملفات Backend غير المستخدمة
echo ====================================
echo.

echo [1/2] حذف الملفات غير المستخدمة...

REM حذف الملفات التجريبية
if exist "index_fixed.js" (
    del "index_fixed.js"
    echo   ✅ تم حذف index_fixed.js
) else (
    echo   ⚠️  index_fixed.js غير موجود
)

if exist "fix_script.js" (
    del "fix_script.js"
    echo   ✅ تم حذف fix_script.js
) else (
    echo   ⚠️  fix_script.js غير موجود
)

echo.
echo [2/2] الملفات المتبقية:
dir /b *.js

echo.
echo ====================================
echo   ✅ تم التنظيف بنجاح!
echo ====================================
echo.
pause
