# DEPLOY YOUR GEMINI API KEY - READY TO GO

## ✅ System Status

- Firebase CLI: ✅ Authenticated (cashtrack000@gmail.com)
- Firebase Project: ✅ Configured (cashtrack-98bd9)
- Cloud Functions: ✅ Ready to deploy
- Flutter App: ✅ Ready (needs project ID update)
- Deployment Script: ✅ Ready (deploy-now.ps1)

**Everything is ready. You can deploy now.**

---

## 🚀 3-Minute Deployment Process

### Step 1: Get Your New API Key (2 minutes)

Your old key is compromised: `AIzaSyCl0ZE7eLPbRaKFhddBQA_IkcB1JAxmhrY`

Create a new one:
1. Open https://console.cloud.google.com
2. Search for and go to **APIs & Services > Credentials**
3. Click **+ Create Credentials > API Key**
4. Copy the new key

**You now have your new API key. Keep it in your clipboard.**

---

### Step 2: Run the Deployment Script (1 minute)

Open PowerShell in `c:\HARMONIA.ai`:

```powershell
.\deploy-now.ps1
```

**When the script asks for your API key:**
- Paste your NEW key from Step 1
- Press Enter

The script will:
1. Verify your Firebase project ✓
2. Deploy your API key as a secret ✓
3. Install Cloud Functions dependencies ✓
4. Deploy Cloud Functions to Firebase ✓
5. Tell you the completion message ✓

**Total time**: ~1 minute (most of it is npm install)

---

### Step 3: Update Your Flutter Code (Less than 1 minute)

After the script completes, edit this file:

**File**: `lib/features/assistant/services/ai_service.dart`

Find line 12-14 and replace:

```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

With:

```dart
static const String _functionsUrl =
    'https://us-central1-cashtrack-98bd9.cloudfunctions.net/getAIResponse';
```

Save the file.

---

### Step 4: Test (1 minute)

```powershell
flutter clean
flutter pub get  
flutter run
```

Once the app opens:
1. Navigate to the AI Assistant tab (bottom navigation)
2. Type "Hi"
3. You should see a typing indicator
4. The AI will respond with context-aware wellness advice

**That's it!** 🎉

---

## 📋 Checklist

- [ ] Old API key found and understood to be compromised
- [ ] New API key created and copied
- [ ] PowerShell opened in c:\HARMONIA.ai
- [ ] `.\deploy-now.ps1` executed
- [ ] Script completed successfully
- [ ] Project ID updated in ai_service.dart (cashtrack-98bd9)
- [ ] `flutter clean && flutter pub get` run
- [ ] `flutter run` executed
- [ ] App opened
- [ ] AI Assistant tested and works

---

## ⏱️ Total Time: ~10 minutes

- Get new API key: 2 minutes
- Run deployment script: 1 minute  
- Update code: 1 minute
- Flutter rebuild & test: 5 minutes
- **Total**: ~10 minutes

---

## 🆘 If Something Goes Wrong

### Script fails on "Deploy API Key Secret"
- Make sure you pasted your NEW key (not the old one)
- Make sure Firebase CLI has internet connection
- Try running again: `.\deploy-now.ps1`

### Script fails on "Deploy Cloud Functions"
- Make sure Node.js is installed: `node --version` (needs 14+)
- Try: `cd functions && npm install && cd ..`
- Then run: `firebase deploy --only functions`

### App won't connect to AI after rebuilding
- Check that you updated the project ID to `cashtrack-98bd9`
- Check that you ran `flutter clean` before rebuilding
- Look at Cloud Function logs: `firebase functions:log`

### What went wrong overall?
See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for troubleshooting section

---

## 📁 Important Files

These files are already set up for you:

- ✅ `.firebaserc` - Firebase project configured
- ✅ `deploy-now.ps1` - Deployment script
- ✅ `functions/src/getAIResponse.ts` - Cloud Function implementation
- ✅ `lib/features/assistant/services/ai_service.dart` - Flutter service
- ✅ `google-services.json` - Firebase credentials

All you need to do is run the script and update the project ID.

---

## ✨ Success Indicator

When everything works, you'll see:

```
✔ Deploy complete!
Project Console: https://console.firebase.google.com/project/cashtrack-98bd9
```

And in your Flutter app:
- AI Assistant tab shows "Start a conversation"
- You can type messages
- AI responds with wellness advice
- Messages persist after app restart

---

## 🎯 Now: Run This Command

```powershell
.\deploy-now.ps1
```

That's all you need to do. The script handles everything else.

---

**Status**: ⚠️ AWAITING USER ACTION  
**Next**: Run `.\deploy-now.ps1` in PowerShell

Your Harmonia AI is 10 minutes away from having a working AI Assistant! 🚀
