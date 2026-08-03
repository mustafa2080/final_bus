@echo off
echo 🔧 Testing MyBus App Fixes...
echo.

echo 📱 Step 1: Building the app...
flutter clean
flutter pub get

echo.
echo 🔥 Step 2: Deploying Firestore rules...
firebase deploy --only firestore:rules

echo.
echo 🚀 Step 3: Running the app in debug mode...
flutter run

echo.
echo ✅ All fixes applied! Test the following:
echo - Navigate between screens
echo - View notifications  
echo - Try logging out
echo - Check student data access
echo - Create absence requests
echo.
pause
