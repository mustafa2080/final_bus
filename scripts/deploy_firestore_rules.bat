@echo off
echo Deploying Firestore rules...
firebase deploy --only firestore:rules
echo Firestore rules deployed successfully!
pause
