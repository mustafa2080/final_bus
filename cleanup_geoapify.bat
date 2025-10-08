@echo off
echo ========================================
echo Cleaning Geoapify Files
echo ========================================
echo.

echo Deleting geoapify_config.dart...
if exist "lib\config\geoapify_config.dart" (
    del "lib\config\geoapify_config.dart"
    echo [OK] geoapify_config.dart deleted
) else (
    echo [SKIP] geoapify_config.dart not found
)

echo.
echo Deleting geoapify_service.dart...
if exist "lib\services\geoapify_service.dart" (
    del "lib\services\geoapify_service.dart"
    echo [OK] geoapify_service.dart deleted
) else (
    echo [SKIP] geoapify_service.dart not found
)

echo.
echo Deleting geoapify_map.dart...
if exist "lib\widgets\geoapify_map.dart" (
    del "lib\widgets\geoapify_map.dart"
    echo [OK] geoapify_map.dart deleted
) else (
    echo [SKIP] geoapify_map.dart not found
)

echo.
echo ========================================
echo Cleanup Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Run: flutter clean
echo 2. Run: flutter pub get
echo 3. Update Socket.IO URL in bus_tracking_screen.dart
echo 4. Test the application
echo.
pause
