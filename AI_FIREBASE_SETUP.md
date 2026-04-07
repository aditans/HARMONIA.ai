# Harmonia AI - Firebase Integration Setup Guide

## ⚠️ IMPORTANT SECURITY NOTE

**NEVER paste API keys directly in code or chat.** Always use Firebase Secrets Manager to securely store sensitive credentials.

For deployment instructions, see: [GEMINI_API_DEPLOYMENT.md](./GEMINI_API_DEPLOYMENT.md)

---

## Overview
The Harmonia AI chatbot is now integrated with Firestore to access user workout data and powered by Google's Gemini API through Firebase Cloud Functions. This guide will walk you through the complete setup process.

---

## Architecture Overview

```
Flutter App (AIService)
    ↓
  REST API
    ↓
Firebase Cloud Function (getAIResponse)
    ↓ (fetches user data)
Cloud Firestore (sessions, user data)
    ↓ (calls API)
Google Gemini API
```

---

## Prerequisites

- Firebase Project created (go to [firebase.google.com](https://firebase.google.com))
- Google Cloud Project linked to Firebase
- Gemini API enabled in Google Cloud Console
- Node.js and npm installed (for deploying Cloud Functions)
- Flutter app with Firebase configured

---

## Step 1: Set Up Gemini API Key

### 1.1 Enable Gemini API in Google Cloud
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to **APIs & Services** > **Enabled APIs & Services**
4. Click **+ Enable APIs and Services**
5. Search for **"Generative Language API"** (or "Gemini API")
6. Click **Enable**

### 1.2 Create API Key
1. Go to **APIs & Services** > **Credentials**
2. Click **+ Create Credentials** > **API Key**
3. Copy the API key (you'll use this in Cloud Functions)
4. (Optional) Restrict the API key to only use "Generative Language API"

---

## Step 2: Deploy Cloud Function

The Cloud Function is already written in `functions/src/getAIResponse.ts`. Follow these steps to deploy it:

### 2.1 Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2.2 Initialize Functions (if not done)
```bash
cd functions
npm install
```

### 2.3 Set Gemini API Secret
```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste your API key when prompted
```

### 2.4 Deploy Functions
```bash
firebase deploy --only functions
```

If you want to deploy only the getAIResponse function:
```bash
firebase deploy --only functions:getAIResponse
```

**Success output** should show:
```
Function URL (getAIResponse): https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse
```

---

## Step 3: Update Flutter App with Cloud Function URL

### 3.1 Get Your Project ID
1. Go to Firebase Console
2. Click on **Project Settings** (gear icon)
3. Copy your **Project ID** (e.g., `harmonia-ai-abc123`)

### 3.2 Update AIService
Edit `lib/features/assistant/services/ai_service.dart` and replace:

```dart
static const String _functionsUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';
```

With your actual project ID:

```dart
static const String _functionsUrl =
    'https://us-central1-harmonia-ai-abc123.cloudfunctions.net/getAIResponse';
```

---

## Step 4: Set Up Firestore Security Rules

The AI service needs to read user session data and write chat history. Update your Firestore security rules:

**Go to Firebase Console > Firestore > Rules**

Replace the rules with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write their own chat history
    match /chatHistory/{uid}/messages/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // Allow authenticated users to read sessions (for AI context)
    match /sessions/{sessionId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.uid;
      allow create, update, delete: if request.auth != null && request.auth.uid == request.resource.data.uid;
    }
    
    // Allow users to read/write their profile
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

Click **Publish** to save.

---

## Step 5: Test the Integration

### Test from Flutter App
1. Run the app: `flutter run -d <device>`
2. Go to the **AI Assistant** screen
3. Send a test message: "What should I focus on today?"
4. You should see:
   - User message appears immediately
   - Typing indicator shows
   - AI response appears within 10 seconds (first call may take longer)
   - Response is saved to Firestore

### Troubleshooting

**Error: "User not authenticated"**
- Make sure you're logged into the app before using the AI assistant
- Check that Firebase Authentication is properly configured

**Error: "Could not get auth token"**
- This is a transient issue, usually resolved on retry
- Check that your user is still logged in

**Error: "AI Service returned 401/403"**
- Check that your Cloud Function is deployed correctly
- Verify the URL in AIService matches your Firebase project
- Check that GEMINI_API_KEY secret is set

**Error: "Invalid response format"**
- Check Cloud Function logs in Firebase Console
- Ensure Gemini API is enabled and API key is valid
- Check the Cloud Function response structure matches expected format

**No history loaded on app start**
- First time users won't have history
- Check Firestore database to ensure documents are being created
- Check browser/device date is correct (affects timestamp queries)

---

## Step 6: Monitor and Maintain

### View Cloud Function Logs
```bash
firebase functions:log
```

Or in Firebase Console:
1. Go to **Cloud Functions**
2. Click on **getAIResponse**
3. Click on **Logs** tab

### Monitor Costs
- **Gemini API**: Pay per token (input/output)
- **Cloud Functions**: Free tier includes 2M invocations/month
- **Firestore**: Free tier includes 50K reads/day, 20K writes/day

### Common Maintenance Tasks

**Rotate API Key (recommended yearly)**
```bash
# Create new API key in Google Cloud Console
firebase functions:secrets:set GEMINI_API_KEY  # Enter new key
firebase deploy --only functions:getAIResponse
```

**Debug a failing response**
1. Check Firebase Console Logs for getAIResponse
2. Verify the message was sent with correct format
3. Test Gemini API directly via curl or Postman
4. Check user's recent sessions exist in Firestore

---

## Alternative Deployment Options

### Option A: Deploy to Azure Functions
If you prefer Azure instead of Firebase:

1. Convert the TypeScript function to use Azure SDK:
```typescript
import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

export async function getAIResponse(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // Similar logic but using Azure libraries
    // Access Cosmos DB instead of Firestore
    // Use Azure OpenAI instead of Gemini API (if preferred)
}

app.http('getAIResponse', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: getAIResponse
});
```

2. Deploy to Azure Functions via Azure CLI or VS Code
3. Update AIService URL in Flutter: `https://your-function-app.azurewebsites.net/api/getAIResponse`

### Option B: Use AWS Lambda
1. Use AWS Amplify or SAM framework
2. Deploy Lambda function with Gemini API calls
3. Use DynamoDB for user data instead of Firestore
4. Update Flutter AIService URL accordingly

### Option C: Self-Hosted (Node.js Express)
If you want full control:

```javascript
const express = require('express');
const app = express();

app.post('/api/getAIResponse', async (req, res) => {
    const { message, uid } = req.body;
    // Similar logic using Node.js libraries
    // Access MongoDB instead of Firestore
    // Call Gemini API
});

app.listen(3000, () => console.log('Running on port 3000'));
```

---

## Security Considerations

1. **API Key Protection**
   - Store Gemini API key only in Cloud Function secrets (never in app code)
   - Restrict API key to "Generative Language API" only
   - Rotate keys periodically

2. **Authentication**
   - All AI requests require Firebase Auth token
   - Cloud Function validates token before processing
   - Firestore rules enforce user isolation

3. **Data Privacy**
   - Chat history is stored per-user
   - Users can clear history via app UI
   - Disable analytics if required by privacy laws

4. **Rate Limiting**
   - Consider adding rate limiting in Cloud Function
   - Monitor for abuse via Cloud Function logs

---

## Example: Adding Rate Limiting to Cloud Function

Add this to `functions/src/getAIResponse.ts`:

```typescript
const rateLimit = {};

export const getAIResponse = onCall(
  { secrets: [geminiKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    const now = Date.now();
    
    // Rate limit: 10 requests per minute per user
    if (!rateLimit[uid]) rateLimit[uid] = [];
    
    rateLimit[uid] = rateLimit[uid].filter(t => now - t < 60000);
    
    if (rateLimit[uid].length >= 10) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many requests. Please wait a moment.',
      );
    }
    
    rateLimit[uid].push(now);
    
    // ... rest of function
  },
);
```

---

## What Happens Next

When a user sends a message to the AI:

1. **Flutter App** → `AIService.sendMessage()` captures the message and user ID
2. **Authentication** → Gets Firebase auth token
3. **REST API Call** → Sends to Cloud Function with auth header
4. **Cloud Function** → Validates auth, fetches last 10 user sessions
5. **Firestore** → Retrieves session summaries (exercises, duration, reps)
6. **Prompt Building** → Creates system prompt with user context
7. **Gemini API** → Calls Google's Gemini with system + user message
8. **Response** → Returns AI-generated response (personalized to user activity)
9. **Persistence** → Saves response to user's chatHistory in Firestore
10. **Flutter** → Displays response in chat UI

---

## Next Steps

- ✅ Deploy Cloud Functions
- ✅ Set Gemini API key
- ✅ Update Flutter with correct Cloud Function URL
- ✅ Test in app on your device
- ✅ Monitor costs and logs
- Future: Add voice input/output, streaming responses, custom knowledge base

---

## Support

For issues:
1. Check Cloud Function logs: `firebase functions:log`
2. Check Firestore rules are published
3. Verify API key is set: `firebase functions:secrets:list`
4. Test with curl:
```bash
curl -X POST https://YOUR_URL/getAIResponse \
  -H "Content-Type: application/json" \
  -d '{"data": {"message": "test", "uid": "test-user"}}'
```

5. Check Google Cloud quotas: https://console.cloud.google.com/quotas
