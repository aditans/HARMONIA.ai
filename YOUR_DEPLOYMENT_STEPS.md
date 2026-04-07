# Your Deployment Environment - Setup Status

## Current Environment

**Firebase Authentication**: ✅ Logged in as `cashtrack000@gmail.com`

**Available Firebase Projects**:
- CashTrack (ID: `cashtrack-98bd9`)

**Your Options**:

### Option 1: Use Existing CashTrack Project (Easiest)
Deploy Harmonia AI to your existing CashTrack Firebase project.

```powershell
cd c:\HARMONIA.ai
firebase use cashtrack-98bd9
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

Then update `lib/features/assistant/services/ai_service.dart`:
```dart
static const String _functionsUrl =
    'https://us-central1-cashtrack-98bd9.cloudfunctions.net/getAIResponse';
```

**Pros**: Quick, uses existing project  
**Cons**: Mixes two apps in one Firebase project

---

### Option 2: Create New Harmonia Project (Recommended)
Create a dedicated Firebase project for Harmonia AI.

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add Project**
3. Name: `harmonia-ai` 
4. Complete creation
5. Then deploy using the new project ID

```powershell
cd c:\HARMONIA.ai
firebase use --add
# Select the new harmonia-ai project
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

**Pros**: Clean separation, professional setup  
**Cons**: Takes a few more minutes to create project

---

## ✅ What You Need To Do

### Step 1: Choose Your Project
- **Use CashTrack** → Jump to Step 2
- **Create Harmonia Project** → Go to Firebase Console first, create project, then Step 2

### Step 2: Set Active Project
```powershell
cd c:\HARMONIA.ai

# If using CashTrack:
firebase use cashtrack-98bd9

# If using new project:
firebase use --add
# Then select the new project
```

### Step 3: Verify Secret Can Be Deployed
```powershell
firebase functions:secrets:list
```

Should show an empty list (or existing secrets from other projects).

### Step 4: Deploy Your API Key
```powershell
firebase functions:secrets:set GEMINI_API_KEY
```

When prompted, paste your **NEW** Gemini API key (the one you created after rotating the exposed key).

### Step 5: Verify Deployment
```powershell
firebase functions:secrets:list
```

Should show `GEMINI_API_KEY` in the list.

### Step 6: Deploy Cloud Functions
```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

Watch for success message with the function URL.

### Step 7: Update Flutter Code
Edit: `lib/features/assistant/services/ai_service.dart`

Find:
```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

If using CashTrack, replace with:
```dart
static const String _functionsUrl =
    'https://us-central1-cashtrack-98bd9.cloudfunctions.net/getAIResponse';
```

If using new project, replace `YOUR_PROJECT_ID` with your actual project ID.

### Step 8: Rebuild and Test
```powershell
flutter clean
flutter pub get
flutter run
```

Test the AI Assistant in the app.

---

## 🎯 Quick Decision Tree

```
Do you want to keep it simple?
├─ YES → Use CashTrack project (Option 1)
└─ NO → Create new Harmonia project (Option 2)
```

---

## ⏱️ Time Estimates

**Option 1 (Use CashTrack)**: 5-10 minutes
- Set project
- Deploy secret
- Deploy functions  
- Update code

**Option 2 (New Project)**: 15-20 minutes
- Create project in Firebase Console (5 min)
- Set project locally
- Deploy secret
- Deploy functions
- Update code

---

## 📝 Commands Cheat Sheet

```powershell
# Check current setup
firebase projects:list
firebase use                          # Show active project

# Setup for CashTrack
firebase use cashtrack-98bd9

# Setup for new project
firebase use --add

# Deploy API key secret
firebase functions:secrets:set GEMINI_API_KEY

# Verify secret
firebase functions:secrets:list

# Deploy functions
firebase deploy --only functions

# View Cloud Function logs
firebase functions:log

# Clean Flutter build
flutter clean && flutter pub get && flutter run
```

---

## ⚠️ Don't Forget

- [ ] Rotate your exposed API key first
- [ ] Use your NEW API key during `secrets:set`
- [ ] Update the project ID in `ai_service.dart`
- [ ] Run `flutter clean && flutter pub get` before testing
- [ ] Check Cloud Function logs if AI doesn't respond

---

## 🆘 If Something Goes Wrong

**Secret won't deploy?**
- Verify project is set: `firebase use`
- Try: `firebase functions:secrets:list`

**Functions won't deploy?**
- Check Node.js version: `node --version` (needs 20+)
- Reinstall dependencies: `cd functions && npm install && cd ..`
- View logs: `firebase functions:log`

**App won't connect to AI?**
- Verify project ID in `ai_service.dart` matches your Firebase project
- Check Cloud Function logs: `firebase functions:log`
- Rebuild app: `flutter clean && flutter pub get && flutter run`

---

## ✨ Success Looks Like

After completion, you'll see:
1. ✅ `firebase functions:secrets:list` shows `GEMINI_API_KEY`
2. ✅ `firebase deploy --only functions` completes with "Deploy complete!"
3. ✅ Flutter app builds without errors
4. ✅ AI Assistant responds to messages in the app
5. ✅ Messages persist after app restart

---

**Ready? Start with Step 1 above!**

Choose your project option and begin deployment.

Your Firebase authentication is already set up, so you're ready to go. 🚀
