<div align="center">

# 🧘 Harmonia AI

**A Flutter wellness app powered by real-time computer vision, on-device ML, and generative AI coaching**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Functions-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-On--Device%20ML-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![MediaPipe](https://img.shields.io/badge/MediaPipe-Pose%20Landmarker-00A98F)](https://developers.google.com/mediapipe)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#license)

</div>

---

Harmonia AI turns your phone's camera into a real-time fitness and posture coach. It tracks exercise reps, scores yoga poses, monitors study-session focus, and answers questions through a Gemini-powered assistant — all backed by on-device ML models so the core experience stays fast and private.

This repo contains **both** the Flutter mobile app and the Python ML pipelines used to train the models it ships with.

<p align="center">
  <img src="docs/screenshots/hero.png" alt="Harmonia AI app screens" width="800">
  <br>
  <sub><i>Add your own screenshots/GIFs here — a 3–4 image row of Exercise, Yoga, Focus, and Assistant modes converts browsers into stars ⭐</i></sub>
</p>

---

## ✨ Core Modes

| Mode | What it does |
|---|---|
| 🏋️ **Exercise** | Live rep counting and posture-quality scoring from camera pose landmarks |
| 🧘 **Yoga** | Pose classification with accuracy, hold-time, and stability feedback |
| 📚 **Study Focus** | Tracks focus percentage, distraction events, and pomodoros completed |
| 🤖 **AI Assistant** | Gemini-powered coach with context from your last 7 days of sessions |

## 🏗 Architecture

```
Flutter UI
  │
  ├─► Firebase Auth ─────────► User identity
  ├─► Firestore ──────────────► Sessions · chat history · profile
  ├─► Cloud Functions ────────► AI responses · stats aggregation
  ├─► Firebase AI (fallback) ─► Direct Gemini access
  └─► On-device TFLite models ─► Exercise / Posture / Yoga inference
```

**Pipeline:** camera frame → MediaPipe pose extraction → landmark normalization → on-device model inference → live UI feedback (counters, scores, cues).

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart) |
| Computer vision | MediaPipe Pose Landmarker |
| On-device inference | TensorFlow Lite |
| Model training | Python, TensorFlow/Keras, scikit-learn |
| Auth & database | Firebase Auth, Firestore |
| Backend logic | Firebase Cloud Functions (TypeScript) |
| Generative AI | Gemini (via Cloud Functions, with Firebase AI Logic fallback) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- A configured Firebase project connected to this app (`google-services.json`, `.firebaserc`, etc.)
- Python 3.10+ if you want to run or retrain the ML pipelines

### Run the app

```powershell
flutter pub get
flutter run
```

### Verify code quality

```powershell
flutter analyze
```

### Build a debug APK

```powershell
flutter build apk --debug
```

> **Firebase setup:** this project expects Firebase integration files (`google-services.json`, `firestore.rules`, `storage.rules`, `firebase.json`) to already be present and pointed at your own Firebase project before running.

---

## 📁 Repository Layout

```text
HARMONIA.ai/
├── lib/                 # Flutter app source
│   ├── main.dart         # Entry point + Firebase init
│   ├── app.dart           # Root MaterialApp + router
│   └── features/assistant/services/ai_service.dart
├── functions/            # Firebase Cloud Functions (TypeScript)
│   ├── getAIResponse.ts   # Gemini chat replies
│   ├── saveSession.ts     # Persists exercise/yoga/focus sessions
│   └── getUserStats.ts    # Aggregates user metrics
├── pipelines/             # ML preprocessing + training scripts
│   ├── exercise_pipeline.py
│   └── posture_pipeline.py
├── yoga_pipeline.py       # Yoga classifier training + export
├── assets/models/         # Exported TFLite models + labels
├── .context/               # Local datasets and downloaded pose assets
└── android/                # Android host project
```

---

## 🗄 Data Model

<details>
<summary><b>users/{uid}</b></summary>

| Field | Type |
|---|---|
| `displayName` | string |
| `email` | string |
| `createdAt` | timestamp |
| `streakDays` | number |
| `totalSessions` | number |

</details>

<details>
<summary><b>sessions/{sessionId}</b></summary>

| Field | Type |
|---|---|
| `uid` | string |
| `type` | `exercise` \| `yoga` \| `focus` |
| `startedAt` / `endedAt` | timestamp |
| `durationSeconds` | number |
| `metrics` | object *(shape depends on `type`, see below)* |

**Exercise metrics:** `exercise`, `reps`, `sets`, `avgAngle`, `postureScore`
**Yoga metrics:** `pose`, `holdDurationSec`, `stabilityScore`, `accuracyScore`
**Focus metrics:** `focusPercent`, `distractionEvents`, `pomodorosCompleted`

</details>

<details>
<summary><b>chatHistory/{uid}/messages/{msgId}</b></summary>

| Field | Type |
|---|---|
| `role` | `user` \| `assistant` |
| `content` | string |
| `timestamp` | timestamp |

</details>

---

## 🤖 AI Assistant

The assistant runs through two paths, so chat stays available even if one transport fails:

1. **Callable Cloud Function** — primary path, includes server-side Firestore context
2. **Firebase AI Logic fallback** — direct Gemini access if the callable path is unavailable

For weekly-routine questions ("how'd my week look?"), the assistant automatically pulls the user's profile and the last 7 days of session documents from Firestore before responding.

---

## 🧠 ML Training Pipelines

Three independent pipelines produce the models shipped in `assets/models/`. Each is a plain Python script structured like a notebook — see [Notebook Workflow](#notebook-workflow) below if you'd rather work in cells.

### 1. Exercise Pipeline
**Goal:** classify exercises from MediaPipe pose landmarks.

| | |
|---|---|
| Script | `pipelines/exercise_pipeline.py` |
| Data source | `.context/dataset/EXERCISE_DATASET/DATASET` (one folder per class) |
| Preprocessing | Extract up to 33 landmarks per image → normalize by torso scale (centered on mid-hip) → 99-value feature vector |
| Training | Dense classifier, `EarlyStopping` + `ModelCheckpoint` + `ReduceLROnPlateau` |
| Output | `ExerciseClassifier_best.keras` → `assets/models/exercise_classifier.tflite` + labels |

```powershell
python pipelines/exercise_pipeline.py
```

### 2. Posture Pipeline
**Goal:** binary upright/slouched classifier from body geometry (not raw images).

| | |
|---|---|
| Script | `pipelines/posture_pipeline.py` |
| Data source | YOLO-style keypoint labels in `.context/dataset/POSTURE_DATASET/labels` |
| Preprocessing | Extract shoulder/hip keypoints → compute torso and shoulder tilt → 12-value feature vector → binary label (1 = upright, 0 = slouched) |
| Training | Compact dense classifier |
| Output | `PostureClassifier_best.keras` → `assets/models/posture_classifier.tflite` + labels |

```powershell
python pipelines/posture_pipeline.py
```

### 3. Yoga Pipeline
**Goal:** classify yoga poses using a two-stage skeleton + landmark approach.

| | |
|---|---|
| Script | `yoga_pipeline.py` |
| Data source | `.context/dataset/DATASET/TRAIN` and `.../TEST` |
| Stage 1 — Skeletonization | MediaPipe pose → draw skeleton-only on black canvas (strips background, clothing, lighting noise) |
| Stage 2 — Classification | Extract 33 landmarks → 99-value feature vector → train `YogaLandmarkClassifier` |
| Output | `YogaConvo2d_best.keras` → `assets/models/yoga_classifier.tflite` + labels |

```powershell
python yoga_pipeline.py
```

### Environment variables

| Variable | Purpose |
|---|---|
| `EXERCISE_EPOCHS` | Override exercise training epochs |
| `POSTURE_EPOCHS` | Override posture training epochs |
| `YOGA_EPOCHS` | Override yoga training epochs |
| `YOGA_PLOT_RESULTS` | Set to `1` to plot training curves + confusion matrix |

```powershell
$env:YOGA_EPOCHS = '10'
$env:YOGA_PLOT_RESULTS = '1'
python yoga_pipeline.py
```

<a name="notebook-workflow"></a>
<details>
<summary><b>📓 Notebook-friendly cell breakdown</b></summary>

Each pipeline follows the same stage order, so it's easy to split into `.ipynb` cells if you prefer interactive experimentation:

1. **Imports & setup** — numpy, pandas, cv2, mediapipe, tensorflow, sklearn; define data/output paths
2. **Dataset exploration** — count classes, inspect samples, verify directory structure
3. **Preprocessing** — MediaPipe pose detection, landmark normalization, skeletonization, train/val/test split
4. **Feature engineering** — landmarks → numeric feature vectors, posture geometry features, class labels
5. **Model definition** — Keras architecture (dense or CNN), Adam optimizer, sparse categorical cross-entropy
6. **Training** — `model.fit()` with `EarlyStopping`, `ModelCheckpoint`, `ReduceLROnPlateau`
7. **Evaluation** — validation/test metrics, confusion matrix, training curves
8. **Export** — save best Keras checkpoint → convert to TFLite → write labels file
9. **Inference test** — run one sample through the exported model to sanity-check predictions

</details>

---

## ✅ Testing Checklist

<details>
<summary><b>ML pipeline validation</b></summary>

- [ ] Dataset path exists and is populated
- [ ] Landmark extraction succeeds on sample data
- [ ] Training loss decreases across epochs
- [ ] Validation accuracy is stable (not overfitting)
- [ ] Confusion matrix matches expected class set
- [ ] TFLite export completes without error
- [ ] Labels file order matches model output indices

</details>

<details>
<summary><b>App smoke tests</b></summary>

- [ ] App launches without crash
- [ ] Firebase Auth sign-in succeeds
- [ ] Camera permission is requested and granted
- [ ] Exercise mode counts reps correctly
- [ ] Yoga mode detects pose + reports accuracy
- [ ] Posture feedback correctly shows upright/slouched
- [ ] AI assistant returns a contextual response

</details>

---

## 🩺 Troubleshooting

| Symptom | Fix |
|---|---|
| Flutter build fails | `flutter clean && flutter pub get && flutter analyze` |
| Model files missing at runtime | Confirm files exist under `assets/models/` and are declared in `pubspec.yaml` |
| Pipeline can't find dataset | Place data under `.context/dataset/` matching the expected structure per pipeline |
| MediaPipe pose model won't download | Pipelines auto-download the landmarker on first run — ensure network access |
| Assistant can't answer weekly questions | Confirm the user is signed in and `users/{uid}` + recent `sessions` docs exist in Firestore |

---

## 🗺 Roadmap

- [ ] Checked-in `.ipynb` notebooks alongside the pipeline scripts
- [ ] Expanded exercise class coverage
- [ ] Session history charts in-app
- [ ] Wearable integration for heart-rate-aware coaching

## 🤝 Contributing

When adding a new ML pipeline or notebook:

1. Put source in `pipelines/` or a dedicated module
2. Document the preprocessing steps in this README
3. Save the best checkpoint and TFLite export paths under `assets/models/`
4. Add a short usage section here
5. Keep exported models under `assets/models/`

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
<sub>Built with Flutter, Firebase, MediaPipe, and TensorFlow Lite</sub>
</div>
