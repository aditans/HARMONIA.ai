# Quick Deployment Checklist

Follow this checklist to deploy your Gemini API key to Firebase Functions.

## Pre-Deployment

- [ ] **Rotate exposed API key**
  - Go to [Google Cloud Console](https://console.cloud.google.com)
  - Delete: `AIzaSyCl0ZE7eLPbRaKFhddBQA_IkcB1JAxmhrY`
  - Create new API key

## Deployment Commands

Copy and paste these commands in PowerShell from `c:\HARMONIA.ai`:

### 1. Login to Firebase
```powershell
firebase login
```
✓ This opens your browser for authentication

### 2. Set Active Project
```powershell
firebase use --add
```
✓ Select your Firebase project when prompted

### 3. Deploy API Key Secret
```powershell
firebase functions:secrets:set GEMINI_API_KEY
```
✓ Paste your NEW API key when prompted (not the exposed one)

### 4. Verify Secret
```powershell
firebase functions:secrets:list
```
✓ You should see `GEMINI_API_KEY` in the list

### 5. Install Function Dependencies
```powershell
cd functions
npm install
cd ..
```
✓ Installs firebase-admin and firebase-functions

### 6. Deploy Functions
```powershell
firebase deploy --only functions
```
✓ Watch for the deployment URL output

### 7. Update App Code
Edit: `lib/features/assistant/services/ai_service.dart`

Find:
```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

Replace `YOUR_PROJECT_ID` with your Firebase project ID (from google-services.json or Firebase Console)

### 8. Rebuild App
```powershell
flutter pub get
flutter run
```
✓ App should build and run without errors

## Verification

- [ ] Secret created: `firebase functions:secrets:list` shows GEMINI_API_KEY
- [ ] Functions deployed: No errors in `firebase deploy --only functions`
- [ ] Project ID updated in AIService
- [ ] App rebuilt successfully: `flutter run` completed
- [ ] AI Assistant responds to messages (test in app)

## Test in App

1. Open Harmonia AI app
2. Navigate to AI Assistant tab
3. Send message: "Hi"
4. Should see typing indicator → response appears

## Troubleshooting

**Problem**: "No currently active project"
```powershell
firebase use --add
```

**Problem**: Secret not found
```powershell
firebase functions:secrets:list
firebase functions:secrets:set GEMINI_API_KEY
```

**Problem**: Deployment fails
```powershell
cd functions && npm install && cd ..
firebase deploy --only functions
```

**Problem**: App still won't connect to AI
- Check Cloud Function logs: `firebase functions:log`
- Verify project ID in AIService matches `google-services.json`
- Rebuild app: `flutter clean && flutter pub get && flutter run`

## Reference Files

- Deployment Guide: [GEMINI_API_DEPLOYMENT.md](GEMINI_API_DEPLOYMENT.md)
- Firebase Setup: [AI_FIREBASE_SETUP.md](AI_FIREBASE_SETUP.md)
- Cloud Function: [functions/src/getAIResponse.ts](functions/src/getAIResponse.ts)
- AI Service: [lib/features/assistant/services/ai_service.dart](lib/features/assistant/services/ai_service.dart)

## Success Indicator

When complete, you should see:
```
✔ Deploy complete!
Project Console: https://console.firebase.google.com/project/YOUR_PROJECT_ID
```

And the AI Assistant will respond to messages in the app.
