@echo off
echo 🧹 Cleaning up duplicate welcome notifications...
echo.

echo 📱 Step 1: Clean build
flutter clean
flutter pub get

echo.
echo 🔥 Step 2: Deploy updated Firestore rules
firebase deploy --only firestore:rules

echo.
echo 🗑️ Step 3: Clean up old notification records (optional)
echo You can manually delete old welcome_records in Firebase Console if needed

echo.
echo 🚀 Step 4: Test the fixed app
flutter run

echo.
echo ✅ Fixed Issues:
echo - ❌ Multiple welcome notifications → ✅ Single welcome notification
echo - ❌ Notifications sent on every login → ✅ Only sent on registration
echo - ❌ Notifications sent to all users → ✅ Only sent to new parents
echo - ❌ No duplicate prevention → ✅ Duplicate prevention implemented
echo.
pause
