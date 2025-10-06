@echo off
echo 🔧 Testing Splash Screen Fixes...
echo.

echo 📱 Step 1: Clean and rebuild...
flutter clean
flutter pub get

echo.
echo 🔥 Step 2: Deploy Firestore rules...
firebase deploy --only firestore:rules

echo.
echo 🚀 Step 3: Run app and test splash screen...
echo - The app should start normally
echo - Splash screen should navigate to login
echo - No more null check errors
echo - Navigation should work properly
echo.

flutter run

echo.
echo ✅ Test completed! Check:
echo - ✅ Splash screen loads without errors
echo - ✅ Navigation works from splash to login
echo - ✅ Login screen loads properly
echo - ✅ No more "Null check operator used on a null value" errors
echo.
pause
