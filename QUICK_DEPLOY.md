# 🚀 DEPLOY YOUR API KEY - Quick Start

Your Firebase is ready. Follow these 3 steps:

## Step 1: Get Your New API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Delete the exposed key: `AIzaSyCl0ZE7eLPbRaKFhddBQA_IkcB1JAxmhrY`
3. Create a NEW API key
4. Copy it

## Step 2: Run the Deployment Script

Open PowerShell in `c:\HARMONIA.ai` and run:

```powershell
.\deploy-now.ps1
```

When prompted, paste your NEW API key (from Step 1).

The script will:
- Deploy your API key to Firebase as a secret
- Deploy the Cloud Functions
- Tell you what to do next

## Step 3: Update Your Flutter Code

Edit: `lib/features/assistant/services/ai_service.dart`

Find line 12-14 (the _functionsUrl):

```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

Change it to:

```dart
static const String _functionsUrl =
    'https://us-central1-cashtrack-98bd9.cloudfunctions.net/getAIResponse';
```

## Step 4: Rebuild and Test

```powershell
flutter clean
flutter pub get
flutter run
```

Test the AI Assistant in the app.

---

**Total time**: ~10 minutes

**That's it!** Your Harmonia AI will have a working AI Assistant! 🎉
