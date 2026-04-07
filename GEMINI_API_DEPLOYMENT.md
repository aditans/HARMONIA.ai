# Gemini API Key Deployment Guide

## ⚠️ SECURITY ALERT

Your API key has been exposed in chat. You must rotate it immediately:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services > Credentials**
3. Find and **DELETE** the exposed key: `AIzaSyCl0ZE7eLPbRaKFhddBQA_IkcB1JAxmhrY`
4. Create a NEW API key
5. Use the new key in the steps below

---

## Step-by-Step Deployment

### Step 1: Authenticate Firebase CLI

```powershell
cd c:\HARMONIA.ai
firebase login
```

This will open your browser. Sign in with your Google account that has access to your Firebase project.

---

### Step 2: Create Firebase Project (if not already created)

If you don't have a Firebase project yet:

1. Go to [Firebase Console](https://firebase.google.com/console)
2. Click **"Add project"**
3. Enter project name: `harmonia-daccb` (or your preferred name)
4. Select country and enable/disable Google Analytics
5. Click **"Create project"**
6. Wait for project to be created (~1-2 minutes)

---

### Step 3: Set Active Firebase Project

```powershell
cd c:\HARMONIA.ai
firebase use --add
```

When prompted:
- Select your Firebase project (e.g., `harmonia-daccb`)
- Enter an alias (can just press Enter to use project ID)

Alternatively, if you know your project ID:

```powershell
firebase use harmonia-daccb
```

---

### Step 4: Deploy Gemini API Key as Secret

```powershell
firebase functions:secrets:set GEMINI_API_KEY
```

**IMPORTANT**: When the prompt appears, paste your **NEW** API key (the one you just created, NOT the exposed one).

Expected output:
```
✔ Created secret [GEMINI_API_KEY] with the value [****...****]
```

---

### Step 5: Verify Secret Was Created

```powershell
firebase functions:secrets:list
```

You should see:
```
┌──────────────────┬──────────┬────────────┐
│ Name             │ Created  │ Updated    │
├──────────────────┼──────────┼────────────┤
│ GEMINI_API_KEY   │ [date]   │ [date]     │
└──────────────────┴──────────┴────────────┘
```

---

### Step 6: Deploy Cloud Functions

Navigate to functions directory and install dependencies:

```powershell
cd c:\HARMONIA.ai\functions
npm install
```

Then deploy the functions:

```powershell
cd c:\HARMONIA.ai
firebase deploy --only functions
```

Expected output:
```
✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/...
```

---

### Step 7: Update AIService URL (CRITICAL)

The Cloud Functions deployment URL will be shown in the output. Update [lib/features/assistant/services/ai_service.dart](../lib/features/assistant/services/ai_service.dart):

Find this line:
```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

Replace `YOUR_PROJECT_ID` with your actual Firebase project ID (e.g., `harmonia-daccb`).

Then rebuild the app:

```powershell
flutter pub get
flutter run
```

---

## Troubleshooting

### Error: "No currently active project"

Solution: Run `firebase use --add` and select your project, or use `firebase use YOUR_PROJECT_ID`.

### Error: "Invalid project selection"

Solution: 
1. Run `firebase projects:list` to see available projects
2. Make sure your Firebase project exists in Firebase Console
3. Use `firebase use --add` to add it

### Error: "Could not authenticate"

Solution: Run `firebase logout` then `firebase login` again.

### API Key Not Working in Cloud Functions

Solution:
1. Verify secret was created: `firebase functions:secrets:list`
2. Check Cloud Function logs: `firebase functions:log`
3. Make sure the functions are using `process.env.GEMINI_API_KEY`

---

## Verification Checklist

- [ ] Exposed API key deleted from Google Cloud Console
- [ ] New API key created
- [ ] Firebase CLI authenticated: `firebase login`
- [ ] Firebase project created (if needed)
- [ ] Firebase project set as active: `firebase use <project-id>`
- [ ] Secret deployed: `firebase functions:secrets:set GEMINI_API_KEY`
- [ ] Secret verified: `firebase functions:secrets:list` shows `GEMINI_API_KEY`
- [ ] Functions deployed: `firebase deploy --only functions`
- [ ] AIService URL updated in code with correct project ID
- [ ] App rebuilt and tested: `flutter run`

---

## Next Steps

1. Complete the steps above
2. Test the AI Assistant in the app
3. Monitor Cloud Function logs: `firebase functions:log`
4. If working, your Harmonia AI app is ready to use!

---

**Reference**: [Firebase Functions Secret Manager](https://firebase.google.com/docs/functions/config-env#secret_manager)
