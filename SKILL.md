You are an expert Flutter developer and Firebase architect. Build me a complete, 
industry-grade Android app called **Harmonia AI** — an AI-powered wellness and 
productivity platform. Below is the full specification. Follow it precisely and 
produce production-quality, modular, maintainable code.

---

## 🧠 PROJECT OVERVIEW

Harmonia AI helps students and fitness enthusiasts track physical fitness, yoga 
posture, and cognitive focus using real-time computer vision — all unified in one 
app. It has four core modules: Exercise Mode, Yoga Mode, Study Focus Mode, and an 
AI Assistant.

---

## 🏗️ TECH STACK

- **Frontend:** Flutter (Dart), Material 3, Riverpod for state management
- **Backend:** Firebase (FirebaseAuth, Cloud Firestore, Firebase Functions, 
  Firebase Storage)
- **ML On-Device:** MediaPipe Pose (33 3D landmarks), TensorFlow Lite 
  (custom yoga classifier)
- **Computer Vision:** camera_android_camerax plugin + custom OpenCV-based 
  processing via platform channels
- **AI Assistant:** Gemini API (via Firebase Functions as a secure proxy)
- **Analytics:** fl_chart for dashboards

---

## 🔐 FIREBASE ARCHITECTURE

### Authentication (FirebaseAuth)
- Email/password signup + login
- Google Sign-In
- Persistent auth state with StreamProvider
- User profile stored in Firestore at: `users/{uid}`

### Firestore Data Model
users/{uid}

displayName: String
email: String
createdAt: Timestamp
streakDays: int
totalSessions: int

sessions/{sessionId}

uid: String
type: "exercise" | "yoga" | "focus"
startedAt: Timestamp
endedAt: Timestamp
durationSeconds: int
metrics: Map<String, dynamic>
→ Exercise: { exercise: String, reps: int, sets: int, avgAngle: double,
postureScore: int }
→ Yoga: { pose: String, holdDurationSec: int, stabilityScore: int,
accuracyScore: int }
→ Focus: { focusPercent: double, distractionEvents: int,
pomodorosCompleted: int }

chatHistory/{uid}/messages/{msgId}

role: "user" | "assistant"
content: String
timestamp: Timestamp


### Security Rules
Write strict Firestore security rules: users can only read/write their own 
documents. Sessions are user-scoped. chatHistory is user-scoped.

### Firebase Functions (Node.js 20, TypeScript)
Create the following HTTPS callable functions:

1. `getAIResponse` — Takes `{ message: String, uid: String }`. Fetches last 10 
   sessions from Firestore for context, builds a system prompt with activity 
   timeline, calls Gemini 1.5 Flash API, returns `{ reply: String }`.

2. `saveSession` — Takes session data, validates it server-side, writes to 
   Firestore `sessions/` collection with a generated ID, updates 
   `users/{uid}.totalSessions` counter atomically.

3. `getUserStats` — Returns aggregated stats: total workout minutes, total 
   focus minutes, streak, and per-week breakdown for charting.

---

## 📱 APP STRUCTURE & NAVIGATION

Use GoRouter for navigation. Bottom navigation bar with 5 tabs:

1. 🏠 Home/Dashboard
2. 💪 Exercise
3. 🧘 Yoga
4. 📚 Study Focus
5. 🤖 AI Assistant

---

## 🏠 HOME / DASHBOARD SCREEN

- Greeting with user's name and current streak (e.g., "🔥 5-day streak")
- Weekly summary cards: Total workout time | Total focus time | Sessions count
- Line chart (fl_chart) showing daily focus % for the last 7 days
- Bar chart showing reps/session for the last 7 exercise sessions
- Recent sessions list (last 5) with type icon, date, and key metric
- Quick-start buttons for each mode

---

## 💪 EXERCISE MODE

UI:
- Full-screen camera preview (CameraX)
- Overlay canvas drawing MediaPipe pose skeleton (33 landmarks connected)
- Rep counter displayed prominently (large font, center-bottom)
- Current angle displayed for the primary joint
- Stage indicator: "UP" / "DOWN" (color-coded green/red)
- Posture feedback banner (e.g., "Keep your back straight!")
- Exercise selector dropdown: Squats, Push-Ups, Lunges, Bicep Curls, Shoulder Press
- Start / Pause / End Session buttons
- On session end: summary modal (reps, sets, duration, posture score) with Save button

Logic:
- Use MediaPipe Pose plugin to get 33 3D landmarks at 30fps
- For each exercise, define relevant joints (e.g., Squat: hip, knee, ankle)
- Calculate angle between 3 points: A, B (vertex), C using dot product formula
- Define stage transitions based on angle thresholds (e.g., angle < 90° = DOWN)
- Increment rep counter on DOWN→UP transition
- Posture score: penalize if spine angle deviates > 15° from vertical
- Provide real-time audio cue on rep completion (flutter_tts: "Good rep!")

---

## 🧘 YOGA MODE

UI:
- Full-screen camera with skeleton overlay
- Detected pose name shown at top (large text)
- Accuracy ring gauge (0–100%) showing current pose accuracy
- Stability meter (wobble detection)
- Hold timer for current pose
- Pose selector: Tree, Warrior I, Warrior II, Downward Dog, Mountain, 
  Child's Pose, Triangle, Cobra
- Visual reference silhouette of target pose (overlay ghost image at 30% opacity)
- Feedback text: "Raise your left arm higher" / "Excellent alignment!"

Logic:
- TensorFlow Lite model: input is a vector of 33 landmark (x, y, z) coordinates 
  (99 floats), output is softmax probabilities over 8 yoga pose classes
- Model file: `assets/models/yoga_classifier.tflite` (you will reference this; 
  generate placeholder loading code)
- Accuracy = cosine similarity between current landmark vector and reference 
  landmark vector for detected pose class
- Stability = standard deviation of hip midpoint position over last 30 frames; 
  low stddev = high stability
- Hold timer starts when accuracy > 70%; resets if accuracy drops below 50%
- Save session when user taps End

---

## 📚 STUDY FOCUS MODE

UI:
- Minimal camera preview (small PiP window, top-right corner)
- Large central timer (Pomodoro: 25:00 countdown)
- Focus percentage ring (updates every 5 seconds)
- Status label: "FOCUSED 🟢" / "DISTRACTED 🔴"
- Pomodoro progress indicator (completed sessions, e.g., ●●●○)
- Break timer (5 min) displayed after each Pomodoro
- Session stats: Total focus time | Distraction count | Avg focus %
- Start / Pause / Reset / End Session controls

Logic:
- Use Google ML Kit Face Detection (real-time, on-device)
- Sample face data every 1 second
- Focus signals (all must be true):
  a) Face detected
  b) Head pitch angle < 20° (not looking down)
  c) Head yaw angle < 25° (not looking away)
  d) Eyes open probability > 0.7 (both eyes)
- Focus score per second: 1 if focused, 0 if distracted
- Running focusPercent = (focusedSeconds / totalSeconds) * 100
- Count distraction events: increment when transitioning from focused → distracted
- Pomodoro logic: 25-min work → 5-min break → repeat; after 4 pomodoros, 15-min 
  long break
- Notification on break start/end using flutter_local_notifications
- Save full session metrics on End

---

## 🤖 AI ASSISTANT MODULE

UI:
- Chat interface (WhatsApp-style bubbles)
- User messages: right-aligned, primary color
- AI messages: left-aligned, surface color, with Harmonia AI avatar
- Text input field with Send button
- Typing indicator (animated dots) while awaiting response
- "Based on your last 7 days" context pill shown above first AI message
- Quick prompt chips: "How did I do this week?", "Suggest a workout", 
  "Tips to improve focus", "Am I improving?"

Logic:
- On send: call `getAIResponse` Firebase Function via `FirebaseFunctions.instance
  .httpsCallable('getAIResponse').call({ message, uid })`
- Display streaming-style response (character by character animation)
- Persist all messages to Firestore `chatHistory/{uid}/messages/`
- Load last 20 messages on open
- The Firebase Function builds context: "User's last 10 sessions summary: 
  [Exercise: 3x Squats avg 15 reps, Yoga: 2x Warrior II 85% accuracy, 
  Focus: 3x sessions avg 72% focus]. Answer wellness questions helpfully."

---

## 🎨 UI / UX REQUIREMENTS

- Use Material 3 with a custom color scheme:
  Primary: #6C63FF (indigo-purple), Secondary: #00BFA5 (teal), 
  Error: #FF5252, Background: #0F0F1A (dark), Surface: #1A1A2E
- Dark theme by default with option to toggle light mode
- Smooth page transitions (slide + fade)
- Lottie animations on session completion
- Skeleton loading screens while data fetches
- All camera screens should handle permission gracefully with a 
  permission request UI if denied
- Responsive layouts for all Android screen sizes

---

## 📦 DEPENDENCIES (pubspec.yaml)

Include and configure:
- firebase_core, firebase_auth, cloud_firestore, firebase_functions, 
  firebase_storage
- google_sign_in
- mediapipe_pose (or camera + custom platform channel stub)
- tflite_flutter
- google_mlkit_face_detection
- camera (CameraX)
- fl_chart
- flutter_riverpod, riverpod_annotation
- go_router
- flutter_tts
- flutter_local_notifications
- lottie
- intl
- cached_network_image
- shimmer (for skeleton loading)

---

## 🗂️ FOLDER STRUCTURE

lib/
  main.dart
  firebase_options.dart
  core/
    theme/
    router/
    constants/
    utils/
  features/
    auth/
      data/ repos/ providers/ screens/
    dashboard/
      data/ providers/ screens/ widgets/
    exercise/
      data/ providers/ screens/ widgets/ services/
    yoga/
      data/ providers/ screens/ widgets/ services/
    focus/
      data/ providers/ screens/ widgets/ services/
    assistant/
      data/ providers/ screens/ widgets/
  shared/
    widgets/
    models/
    services/

functions/
  src/
    index.ts
    getAIResponse.ts
    saveSession.ts
    getUserStats.ts
  package.json
  tsconfig.json

firestore.rules
storage.rules

---

## ✅ ADDITIONAL REQUIREMENTS

1. All Firebase calls must be wrapped in try/catch with user-friendly error 
   SnackBars.
2. Use Riverpod AsyncNotifier for all async state; no raw setState for business 
   logic.
3. MediaPipe and TFLite inference must run on an isolate to keep UI at 60fps.
4. All sessions must be saveable offline (Firestore offline persistence enabled).
5. Write comprehensive inline comments explaining the ML logic (angle 
   calculation, pose classification, focus detection).
6. Firebase Functions must have input validation and return structured error codes.
7. Add a onboarding flow (3 screens) for first-time users explaining each mode.
8. Include a Settings screen: toggle dark/light mode, notification preferences, 
   clear chat history, sign out, account deletion.

---

Start by generating the complete project scaffolding, then implement each module 
one at a time. Begin with: Firebase setup → Auth → Dashboard → Exercise Mode → 
Yoga Mode → Study Focus Mode → AI Assistant → Firebase Functions.
