You are an expert Flutter developer, Firebase architect, and computer vision 
engineer. Build the complete HARMONIA AI app — an industry-grade wellness and 
fitness platform. This prompt focuses on the EXACT, DEEP IMPLEMENTATION of every 
ML feature. Follow every specification precisely.

═══════════════════════════════════════════════════════════════════
PART 1 — MEDIAPIPE POSE: THE MATHEMATICAL ENGINE
═══════════════════════════════════════════════════════════════════

## 1A. THE 33 LANDMARK MAP (Memorize These Indices)

Use these MediaPipe landmark indices throughout all exercise and yoga logic:

FACE:       0=nose, 1=left_eye_inner, 2=left_eye, 3=left_eye_outer,
            4=right_eye_inner, 5=right_eye, 6=right_eye_outer,
            7=left_ear, 8=right_ear, 9=mouth_left, 10=mouth_right

UPPER BODY: 11=left_shoulder, 12=right_shoulder,
            13=left_elbow,    14=right_elbow,
            15=left_wrist,    16=right_wrist,
            17=left_pinky,    18=right_pinky,
            19=left_index,    20=right_index,
            21=left_thumb,    22=right_thumb

CORE:       23=left_hip, 24=right_hip

LOWER BODY: 25=left_knee,  26=right_knee,
            27=left_ankle, 28=right_ankle,
            29=left_heel,  30=right_heel,
            31=left_foot_index, 32=right_foot_index

KEY DERIVED POINTS (compute at runtime):
  midHip    = midpoint(23, 24)
  midShoulder = midpoint(11, 12)
  spineVector = midShoulder - midHip (used for posture scoring)

## 1B. CORE ANGLE CALCULATION FUNCTION (implement once, use everywhere)
```dart
double calculateAngle(
  PoseLandmark a,  // first point
  PoseLandmark b,  // vertex (joint being measured)
  PoseLandmark c   // third point
) {
  final radians = atan2(c.y - b.y, c.x - b.x) 
                - atan2(a.y - b.y, a.x - b.x);
  double angle = (radians * 180 / pi).abs();
  if (angle > 180) angle = 360 - angle;
  return angle;
}
```

Also implement a 3-point visibility check — only process landmarks with 
visibility score > 0.5 to avoid phantom detections:
```dart
bool isVisible(PoseLandmark lm) => lm.likelihood > 0.5;
bool tripletVisible(a, b, c) => isVisible(a) && isVisible(b) && isVisible(c);
```

## 1C. POSTURE DEVIATION SCORE (used in ALL exercise modes)

Spine angle from vertical:
  spineAngle = angle between vector(midHip→midShoulder) and vertical axis [0,-1]
  
  Score mapping:
    spineAngle 0°–10°  → score = 100  (perfect)
    spineAngle 10°–20° → score = 80   (good)
    spineAngle 20°–30° → score = 60   (warning, show text "Straighten your back")
    spineAngle > 30°   → score = 40   (bad, flash red overlay)

## 1D. SMOOTHING FILTER (prevent jitter on mobile)

Apply exponential moving average to all computed angles before using them:
  smoothedAngle = alpha * rawAngle + (1 - alpha) * previousSmoothedAngle
  where alpha = 0.3 (higher = more responsive, lower = smoother)

Store last 5 angle readings per joint in a circular buffer; use median 
to eliminate outlier frames.

═══════════════════════════════════════════════════════════════════
PART 2 — GYM EXERCISE MODE: FULL SPECIFICATION
═══════════════════════════════════════════════════════════════════

Camera orientation: SIDE VIEW preferred for compound lifts (squat, deadlift, 
push-up). FRONT VIEW for curls, shoulder press, lateral raises.

Implement a camera orientation detector:
  offset_angle = angle between nose(0) and midShoulder
  if offset_angle > 25°: user is not side-on → show "Please face sideways" warning

─────────────────────────────────────────────────
EXERCISE 1: BARBELL / BODYWEIGHT SQUAT
─────────────────────────────────────────────────
Primary landmarks: 23(left_hip), 25(left_knee), 27(left_ankle)
Secondary check:   12(right_shoulder), 24(right_hip), 26(right_knee)
Camera: SIDE VIEW

Joint angles to compute:
  knee_angle   = angle(hip[23], knee[25], ankle[27])
  hip_angle    = angle(shoulder[12], hip[24], knee[26])
  ankle_angle  = angle(knee[25], ankle[27], heel[29])
  torso_angle  = angle of vector(hip→shoulder) from vertical

Stage thresholds:
  STANDING (UP):   knee_angle > 160°
  PARALLEL:        knee_angle between 85°–100° (ideal squat depth)
  TOO DEEP:        knee_angle < 80° (warn: "Don't go too deep")
  HALF_REP:        knee_angle between 100°–140° (warn: "Squat deeper")

Rep counting logic:
  stage = "up"   when knee_angle > 160
  stage = "down" when knee_angle < 90
  counter++ when stage transitions from "down" → "up"

Posture feedback rules (check every frame while in DOWN stage):
  if torso_angle > 45°: "Chest up! Lean less forward"
  if ankle_angle < 60°: "Don't let heels rise"
  if knee_x > toe_x + threshold: "Knees caving in! Push knees out"
  if hip_angle < 60°: "Hips too low, this is good — hold!"
  if hip_angle > 100° and knee_angle < 100°: "Go deeper"

Ideal form: knee_angle ≈ 90°, torso_angle < 30°, ankle_angle > 70°

─────────────────────────────────────────────────
EXERCISE 2: PUSH-UP
─────────────────────────────────────────────────
Primary landmarks: 12(right_shoulder), 14(right_elbow), 16(right_wrist)
Secondary check:   24(right_hip), 28(right_ankle)
Camera: SIDE VIEW (person horizontal to camera)

Joint angles to compute:
  elbow_angle = angle(shoulder[12], elbow[14], wrist[16])
  body_line   = angle of vector(shoulder→ankle) from horizontal
                [should be 0°–15° for a plank body position]
  hip_angle   = angle(shoulder[12], hip[24], ankle[28])

Stage thresholds:
  UP position:   elbow_angle > 160°
  DOWN position: elbow_angle < 90°

Rep counting:
  stage = "up"   when elbow_angle > 160
  stage = "down" when elbow_angle < 90
  counter++ on "down" → "up" transition

Posture feedback:
  if body_line > 20°: "Hips sagging! Engage your core"
  if body_line < -10°: "Lower your hips"
  if elbow_angle at bottom > 110°: "Go lower for full range"
  Check: wrist should be directly under shoulder 
    → wrist_x should be within ±0.05 of shoulder_x (normalized coords)
    → if not: "Move hands under shoulders"

─────────────────────────────────────────────────
EXERCISE 3: BICEP CURL (Dumbbell)
─────────────────────────────────────────────────
Primary landmarks (LEFT): 11(left_shoulder), 13(left_elbow), 15(left_wrist)
Primary landmarks (RIGHT): 12(right_shoulder), 14(right_elbow), 16(right_wrist)
Camera: FRONT VIEW — track both arms independently

Joint angles to compute:
  left_elbow_angle  = angle(left_shoulder[11], left_elbow[13], left_wrist[15])
  right_elbow_angle = angle(right_shoulder[12], right_elbow[14], right_wrist[16])

Stage thresholds:
  DOWN (extended): elbow_angle > 160°
  UP (contracted): elbow_angle < 45°

Rep counting: track left and right reps independently
  left_counter++  when left transitions  DOWN → UP
  right_counter++ when right transitions DOWN → UP

Posture feedback:
  if shoulder[11 or 12] moves forward during curl (y-coord changes > 0.05):
    "Keep your elbow pinned — don't swing"
  if wrist rotates (check wrist_z vs elbow_z): "Fully supinate at the top"
  Optimal: angle at bottom ≥ 160°, angle at top ≤ 45°
  If top angle > 60°: "Curl higher for full contraction"

─────────────────────────────────────────────────
EXERCISE 4: SHOULDER PRESS (Overhead Press)
─────────────────────────────────────────────────
Primary landmarks: 11(left_shoulder), 13(left_elbow), 15(left_wrist)
                   12(right_shoulder), 14(right_elbow), 16(right_wrist)
Camera: FRONT VIEW

Joint angles:
  left_elbow_angle  = angle(shoulder, elbow, wrist) — left side
  right_elbow_angle = angle(shoulder, elbow, wrist) — right side
  shoulder_abduction = angle(hip[23], shoulder[11], elbow[13])

Stage thresholds:
  DOWN (start): elbow_angle < 90° AND wrist.y > shoulder.y (wrists at ear level)
  UP (lockout):  elbow_angle > 160°

Rep counting: counter++ when transitions from DOWN → UP (both arms simultaneous)

Posture feedback:
  if lower back arches (spine_angle > 10° backward): "Don't arch — brace core"
  if wrists not in line with shoulders: "Bar path should be vertical"
  if elbows flare > 90° from torso: "Tuck elbows slightly"

─────────────────────────────────────────────────
EXERCISE 5: LUNGE
─────────────────────────────────────────────────
Primary landmarks: 23(left_hip), 25(left_knee), 27(left_ankle)
                   24(right_hip), 26(right_knee), 28(right_ankle)
Camera: SIDE VIEW (or FRONT VIEW)

Joint angles:
  front_knee_angle = angle(hip, front_knee, front_ankle) — lead leg
  back_knee_angle  = angle(hip, back_knee, back_ankle) — trailing leg
  torso_vertical   = spine angle from vertical

Stage thresholds:
  DOWN: front_knee_angle < 90° AND back_knee_angle < 100°
  UP:   front_knee_angle > 160°

Rep counter++ on UP → DOWN → UP cycle

Posture feedback:
  if front_knee passes over toes (knee_x > ankle_x + 0.05 normalized):
    "Keep front knee over ankle"
  if torso_vertical > 15°: "Keep torso upright"
  if back_knee touches ground (back_ankle_y ≈ back_knee_y): 
    "Don't let back knee slam down"

─────────────────────────────────────────────────
EXERCISE 6: DEADLIFT
─────────────────────────────────────────────────
Primary landmarks: 12(shoulder), 24(hip), 26(knee), 28(ankle)
Camera: SIDE VIEW

Joint angles:
  hip_hinge_angle = angle(shoulder[12], hip[24], knee[26])
  knee_angle      = angle(hip[24], knee[26], ankle[28])
  back_angle      = spine deviation from vertical (midShoulder→midHip)

Stage thresholds:
  HINGE (down): hip_hinge_angle < 90° 
  LOCKOUT (up): hip_hinge_angle > 170° AND knee_angle > 170°

Rep counter++ on HINGE → LOCKOUT transition

Posture feedback:
  if back_angle > 20° (rounded): "Keep your back flat — hinge at hips"
  if knee_angle < 150° at lockout: "Fully extend knees at top"
  if hips rise faster than shoulders during pull: 
    "Drive through heels, keep chest up"
  Bar path: wrist should remain directly over mid-foot throughout 
    (wrist_x ≈ ankle_x ± 0.03)

─────────────────────────────────────────────────
EXERCISE 7: LATERAL RAISE
─────────────────────────────────────────────────
Primary landmarks: 11(left_shoulder), 13(left_elbow), 15(left_wrist)
Camera: FRONT VIEW

Angle:
  shoulder_elevation = angle(hip[23], shoulder[11], wrist[15])

Stage thresholds:
  DOWN: shoulder_elevation < 20°
  TOP:  shoulder_elevation between 80°–100° (parallel to floor = ideal)
  TOO HIGH: shoulder_elevation > 110° → "Lower to shoulder height"

Rep counter++ on DOWN → TOP → DOWN

Posture feedback:
  if elbow drops below wrist at top: "Lead with elbows, not wrists"
  if body sways: detect hip lateral shift > 0.03 normalized
    → "Control the movement — no swinging"

─────────────────────────────────────────────────
EXERCISE 8: PULL-UP / CHIN-UP
─────────────────────────────────────────────────
Primary landmarks: 11(left_shoulder), 13(left_elbow), 15(left_wrist)
Camera: FRONT VIEW

Angle:
  elbow_angle = angle(shoulder, elbow, wrist)
  shoulder_angle = angle(hip, shoulder, elbow)

Stage thresholds:
  DEAD HANG (down): elbow_angle > 160°
  TOP (chin over bar): elbow_angle < 60° AND chin[0].y < wrist[15].y

Rep counter++ on DEAD HANG → TOP transition

Posture feedback:
  if body swings: track hip lateral movement across frames
  if chin doesn't clear wrist level: "Pull higher — chin over bar"
  if elbows flare out excessively: "Keep elbows pointing down, not out"

─────────────────────────────────────────────────
EXERCISE 9: PLANK (Hold Timer — No Reps)
─────────────────────────────────────────────────
Primary landmarks: 12(shoulder), 24(hip), 28(ankle)

Detection:
  body_line_angle = angle(shoulder[12], hip[24], ankle[28])
  Plank detected when: body_line_angle between 165°–180° 
                       AND person is horizontal to ground

Mode: HOLD TIMER — count seconds while form is maintained
  Quality check every second:
    if hip sags (hip.y > shoulder.y + ankle.y / 2 + threshold): 
      pause timer, show "Hips sagging!"
    if hips pike (hip too high): pause timer, show "Lower your hips"
  
  Display: hold time, current form quality (GOOD/WARNING/BAD), 
           estimated calories burned

─────────────────────────────────────────────────
EXERCISE 10: JUMPING JACK (Cardio Counter)
─────────────────────────────────────────────────
Primary landmarks: 11,12(shoulders), 15,16(wrists), 27,28(ankles)
Camera: FRONT VIEW

Detection:
  arm_spread = distance(left_wrist[15], right_wrist[16]) normalized by 
               shoulder_width
  leg_spread = distance(left_ankle[27], right_ankle[28]) normalized by 
               hip_width

Stage thresholds:
  CLOSED: arm_spread < 1.2 AND leg_spread < 1.2
  OPEN:   arm_spread > 2.0 AND leg_spread > 1.8

Rep counter++ on CLOSED → OPEN → CLOSED

═══════════════════════════════════════════════════════════════════
PART 3 — YOGA MODE: FULL SPECIFICATION
═══════════════════════════════════════════════════════════════════

## 3A. YOGA CLASSIFICATION ARCHITECTURE

Two-layer system:
  Layer 1 — POSE DETECTOR: Landmark-based angle heuristics (no ML needed 
             for clear poses)
  Layer 2 — TFLite CLASSIFIER: 99-float vector (33 landmarks × x,y,z) 
             → softmax over 15 pose classes (for ambiguous/complex poses)

Normalization before classification:
  1. Translate all landmarks so midHip = origin (0,0,0)
  2. Scale all landmarks so torso height (midHip → midShoulder) = 1.0
  3. Flatten to 99-float array: [lm0.x, lm0.y, lm0.z, lm1.x, ...]

Accuracy scoring (per frame):
  Compare normalized landmark vector to stored REFERENCE VECTOR for each pose
  Use cosine similarity: score = dot(current, reference) / (|current| × |reference|)
  accuracy_percent = score × 100, clamped 0–100

Stability scoring:
  Track midHip position over last 30 frames
  stability = 100 - (stdDev(midHip_positions) × 1000)  [clamped 0–100]

─────────────────────────────────────────────────
YOGA POSE 1: MOUNTAIN POSE (Tadasana)
─────────────────────────────────────────────────
Key landmarks: all full-body
Camera: FRONT VIEW

Angle checks:
  Both arms relaxed at sides:
    left_arm_angle  = angle(shoulder[11], elbow[13], wrist[15]) ≈ 170°–180°
    right_arm_angle = angle(shoulder[12], elbow[14], wrist[16]) ≈ 170°–180°
  Legs straight:
    left_knee_angle  = angle(hip[23], knee[25], ankle[27]) > 170°
    right_knee_angle = angle(hip[24], knee[26], ankle[28]) > 170°
  Spine erect: spine_angle from vertical < 5°

Feedback: "Stand tall", "Relax shoulders", "Weight evenly distributed"
Hold detection: all above met for 3+ seconds → confirm pose

─────────────────────────────────────────────────
YOGA POSE 2: TREE POSE (Vrksasana)
─────────────────────────────────────────────────
Key landmarks: 23,24(hips), 25,26(knees), 27,28(ankles), 
               11,12(shoulders), 15,16(wrists)
Camera: FRONT VIEW

Angle checks:
  Standing leg (right): right_knee_angle > 170°
  Bent leg (left):
    left_knee_angle = angle(hip[23], knee[25], ankle[27]) < 90°
    (foot placed on inner thigh — hip[23].y ≈ knee[25].y from side)
  Hip openness: angle(right_hip, left_hip, left_knee) > 80°
  Arms raised:
    Both wrists.y < shoulders.y (hands above head or at chest/prayer)
    If palms together overhead:
      distance(left_wrist[15], right_wrist[16]) < 0.05 normalized
  Spine: spine_angle < 8°

Feedback:
  if left_knee_angle > 90°: "Raise your foot higher on the inner thigh"
  if spine deviates: "Find your center — look at a fixed point"
  if wrists not meeting: "Bring palms together"

─────────────────────────────────────────────────
YOGA POSE 3: WARRIOR I (Virabhadrasana I)
─────────────────────────────────────────────────
Camera: SIDE VIEW (perpendicular to body)

Angle checks:
  Front knee: angle(hip[23], knee[25], ankle[27]) ≈ 85°–100°
  Back leg: angle(hip[24], knee[26], ankle[28]) > 160° (straight)
  Arms raised: angle(hip[23], shoulder[11], wrist[15]) ≈ 160°–180°
  Torso: square to front, spine vertical (spine_angle from vertical < 10°)
  Hip square check: both hips at same depth (left_hip.z ≈ right_hip.z in 3D)

Feedback:
  if front_knee < 80°: "Bend front knee to 90°"
  if front_knee > 110°: "Bend front knee more"
  if arms not fully raised: "Reach arms fully overhead"
  if back foot not flat: "Ground the outer edge of your back foot"
  if hips not squared: "Square your hips to the front"

─────────────────────────────────────────────────
YOGA POSE 4: WARRIOR II (Virabhadrasana II)
─────────────────────────────────────────────────
Camera: FRONT VIEW

Angle checks (using Google ML Kit reference angles):
  Front knee:     angle(hip[23], knee[25], ankle[27]) ≈ 90°
  Back leg:       angle(hip[24], knee[26], ankle[28]) > 170° (straight)
  Right arm:      angle(right_hip[24], right_shoulder[12], right_elbow[14]) ≈ 90°
  Left arm:       angle(left_hip[23], left_shoulder[11], left_elbow[13]) ≈ 90°
  Both arms parallel to floor:
    Both wrists at ≈ same height as shoulders (wrist.y ≈ shoulder.y ± 0.05)
  Torso upright over hips:
    midShoulder.x ≈ midHip.x (not leaning forward or back)
  Gaze: over front hand (infer from nose[0] direction)

Feedback:
  if front_knee < 80°: "Sink deeper into front knee"
  if right_arm drops: "Keep right arm at shoulder height"
  if torso leans forward: "Stack shoulders over hips"
  if back toes not pointing out 90°: detected via ankle/heel vector

─────────────────────────────────────────────────
YOGA POSE 5: DOWNWARD FACING DOG (Adho Mukha Svanasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Hip angle (inverted V shape):
    angle(shoulder[11], hip[23], knee[25]) ≈ 50°–70° (hips high)
  Arm angle:
    angle(hip[23], shoulder[11], elbow[13]) ≈ 170°–180° (arms straight)
  Knee angle:
    angle(hip[23], knee[25], ankle[27]) > 170° (legs straight OR bent for beginners)
  Spine: neck in neutral alignment (nose[0].y between shoulder and hip vertically)

Body shape check:
  Person forms inverted V — verify:
    hip.y < shoulder.y AND hip.y < ankle.y (hips highest point)

Feedback:
  if hip angle > 80°: "Push hips higher and back"
  if arms bent (elbow_angle < 160°): "Straighten your arms"
  if heels not toward floor (ankle.y too high): 
    "Gently pedal your heels toward the floor"
  if head drops between arms: "Relax your neck"

─────────────────────────────────────────────────
YOGA POSE 6: CHILD'S POSE (Balasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Person folded forward (hips back on heels):
    hip_angle = angle(shoulder[11], hip[23], knee[25]) < 60°
    knee_angle = angle(hip[23], knee[25], ankle[27]) < 50°
  Arms extended forward:
    angle(hip[23], shoulder[11], wrist[15]) ≈ 150°–180°
  All body points low to ground:
    shoulder.y > 0.6 (normalized, lower half of frame)
    wrist.y > 0.5

Feedback:
  if hips not fully back: "Sit hips back toward heels"
  if arms not extended: "Reach arms fully forward"
  "Breathe deeply — hold and relax"

─────────────────────────────────────────────────
YOGA POSE 7: COBRA POSE (Bhujangasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Person prone, upper body raised:
    spine backbend angle = angle between vertical and spine vector > 30°
  Elbow angle:
    angle(shoulder[11], elbow[13], wrist[15]) ≈ 120°–150° (elbows slightly bent)
  Hip contact: hips/legs flat (hip.y ≈ ankle.y in normalized space, both low)
  Shoulder retraction: both shoulders pulled back (shoulder.z < elbow.z)

Feedback:
  if elbows fully locked: "Keep a slight bend in your elbows"
  if shoulders raised to ears: "Drop shoulders away from ears"
  if lower back crunching: "Distribute backbend throughout spine"

─────────────────────────────────────────────────
YOGA POSE 8: TRIANGLE POSE (Trikonasana)
─────────────────────────────────────────────────
Camera: FRONT VIEW

Angle checks:
  Legs wide apart: 
    distance(left_ankle[27], right_ankle[28]) > 1.5× hip_width
  Front leg straight: right_knee_angle > 160°
  Back leg straight: left_knee_angle > 160°
  Side bend:
    angle(right_ankle[28], right_hip[24], right_shoulder[12]) ≈ 165°–175°
    (body tilted to one side, forming a triangle)
  Top arm raised vertical:
    left_wrist[15].y < left_shoulder[11].y (reaching up)
    angle(hip[23], shoulder[11], wrist[15]) ≈ 170°–180°
  Bottom hand toward floor:
    right_wrist[16].y ≈ right_ankle[28].y (or close to it)

Feedback:
  if top arm not vertical: "Extend top arm straight up"
  if front knee bends: "Keep front leg straight"
  if torso tilts forward: "Open your chest to the sky"

─────────────────────────────────────────────────
YOGA POSE 9: PLANK (Phalakasana)
─────────────────────────────────────────────────
Same as GYM PLANK detection — refer to Exercise 9 above.
Add in yoga context: wrist alignment, finger spread cannot be detected 
but remind via text cues.

─────────────────────────────────────────────────
YOGA POSE 10: CHAIR POSE (Utkatasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Knee angle: angle(hip[23], knee[25], ankle[27]) ≈ 90°–110°
  Arms raised: angle(hip[23], shoulder[11], wrist[15]) ≈ 160°–180°
  Torso forward lean:
    spine_angle from vertical ≈ 30°–45° (leaning slightly forward is correct)

Feedback:
  if knee_angle > 120°: "Sit deeper into chair"
  if arms drop: "Reach arms up alongside ears"
  if heels lift: "Ground your heels"

─────────────────────────────────────────────────
YOGA POSE 11: BRIDGE POSE (Setu Bandha Sarvangasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Person supine with hips raised:
    hip.y < shoulder.y AND hip.y < knee.y (hips lifted)
  Knee angle: angle(hip[23], knee[25], ankle[27]) ≈ 90°–100°
  Shoulder–hip–knee roughly linear: 
    angle(shoulder[11], hip[23], knee[25]) ≈ 140°–170°

Feedback:
  if hips not raised enough: "Lift hips higher toward ceiling"
  if knees too wide: "Keep knees hip-width apart"
  "Clasp hands under your body and press into the floor"

─────────────────────────────────────────────────
YOGA POSE 12: SEATED FORWARD BEND (Paschimottanasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Seated, torso folding over legs:
    hip_fold_angle = angle(shoulder[11], hip[23], knee[25]) < 90°
  Legs straight: knee_angle > 160°
  Arms extended forward toward feet:
    wrist.y ≈ ankle.y (reaching feet/shins)

Feedback:
  if knees bent: "Try to straighten your legs"
  if rounding aggressively at lower back: "Hinge from hips, not waist"
  "Walk hands forward with each exhale"

─────────────────────────────────────────────────
YOGA POSE 13: PIGEON POSE (Eka Pada Rajakapotasana)
─────────────────────────────────────────────────
Camera: SIDE or FRONT VIEW

Angle checks (right leg as lead):
  Front leg: right_knee_angle = angle(hip[24], knee[26], ankle[28]) ≈ 70°–90°
             right foot pulled in front (front shin horizontal)
  Back leg: straight back, left_knee_angle > 160°, left leg extended behind
  Torso: upright or folded forward
    if upright: spine_angle from vertical < 20°
    if folded: shoulder.y approaches floor level

Feedback:
  if front foot too close to body: "Slide front foot further forward"
  if hips not even: "Square your hips to the mat"
  if back leg rolling out: "Internally rotate back leg"

─────────────────────────────────────────────────
YOGA POSE 14: CAMEL POSE (Ustrasana)
─────────────────────────────────────────────────
Camera: SIDE VIEW

Angle checks:
  Kneeling, backbend:
    Spine backbend angle from vertical > 45° (significant backbend)
    Hands reaching back toward heels: wrist.y > hip.y
  Knee angle: ≈ 90° (kneeling position)
  Shoulder elevation: shoulders open, not hunching

Feedback:
  if hands don't reach heels: "Use blocks or lift hips forward more"
  if neck strained (head drops back too far): "Keep slight chin tuck"
  "Push hips forward as you arch back"

─────────────────────────────────────────────────
YOGA POSE 15: WARRIOR III (Virabhadrasana III)
─────────────────────────────────────────────────
Camera: SIDE VIEW (T-shape body)

Angle checks:
  Standing leg: right_knee_angle > 165°
  Lifted leg: left leg horizontal
    angle(right_hip[24], left_hip[23], left_ankle[28]) ≈ 170°–180°
    left_ankle.y ≈ right_hip.y (same height)
  Torso horizontal:
    body_line = angle of vector(shoulder→hip) from horizontal ≈ 0°–15°
  Arms forward:
    angle(hip[23], shoulder[11], wrist[15]) ≈ 165°–180°

Feedback:
  if lifted leg drops: "Keep lifted leg at hip height"
  if torso tilts: "Keep spine parallel to the floor"
  if standing knee bends: "Engage standing leg — lock the knee"

═══════════════════════════════════════════════════════════════════
PART 4 — YOGA ACCURACY RATING SYSTEM
═══════════════════════════════════════════════════════════════════

For every yoga pose, compute a TOTAL ACCURACY SCORE (0–100):

  1. Angle score (60% weight):
     For each required angle, compute deviation from ideal:
       angleScore_i = max(0, 100 - (abs(measured - ideal) × 2))
     avgAngleScore = average of all angleScore_i

  2. Stability score (25% weight):
     As described in 3A above (stdDev of midHip)

  3. Body symmetry score (15% weight):
     For bilateral poses: compare left/right angle differences
     symmetryScore = 100 - abs(leftAngle - rightAngle)

  totalAccuracy = (avgAngleScore × 0.60) 
                + (stability × 0.25) 
                + (symmetryScore × 0.15)

Display: Animated ring gauge filling as user improves. Color:
  0–50%:   Red    → "Keep trying"
  50–70%:  Orange → "Getting there"
  70–85%:  Yellow → "Good form"
  85–95%:  Green  → "Excellent!"
  95–100%: Gold   → "Perfect! 🏆"

Hold timer ONLY increments when accuracy > 65%.
Session summary: best accuracy achieved, total hold time, avg stability.

═══════════════════════════════════════════════════════════════════
PART 5 — STUDY FOCUS MODE: FULL SPECIFICATION
═══════════════════════════════════════════════════════════════════

## 5A. Face Detection Setup (Google ML Kit Face Detection)
```dart
final faceDetector = FaceDetector(
  options: FaceDetectorOptions(
    enableClassification: true,   // eye open probability
    enableTracking: true,
    performanceMode: FaceDetectorMode.fast,
    minFaceSize: 0.15,
  ),
);
```

Sample every 1.0 second (not every frame — save battery):
  Use a timer to sample from the camera stream at 1-second intervals.

## 5B. FOCUS DETECTION ALGORITHM

For each 1-second sample, check ALL of the following:

  CHECK 1 — FACE PRESENT:
    faces.isNotEmpty → true/false

  CHECK 2 — EYES OPEN:
    face.leftEyeOpenProbability > 0.7 AND
    face.rightEyeOpenProbability > 0.7
    (both eyes must be open — catches dozing off)

  CHECK 3 — HEAD PITCH (nodding, looking up/down):
    face.headEulerAngleX → pitch
    Focused: abs(pitch) < 20°
    > 20° downward: "Are you reading from a different screen?"
    < -20° upward: "Look at your screen"

  CHECK 4 — HEAD YAW (turning left/right):
    face.headEulerAngleY → yaw
    Focused: abs(yaw) < 25°
    > 25°: "Stay focused on your work"

  CHECK 5 — HEAD ROLL (tilting sideways):
    face.headEulerAngleZ → roll
    Focused: abs(roll) < 30°
    > 30°: "Sit up straight"

  IS_FOCUSED = CHECK 1 AND CHECK 2 AND CHECK 3 AND CHECK 4 AND CHECK 5

## 5C. FOCUS METRICS COMPUTATION
focusedSeconds: int = 0
totalSeconds: int = 0
distractionCount: int = 0
lastFocusState: bool = true
every second:
totalSeconds++
currentState = IS_FOCUSED
if currentState: focusedSeconds++
if lastFocusState == true && currentState == false:
distractionCount++  // only count transition, not sustained distraction
lastFocusState = currentState
focusPercent = (focusedSeconds / totalSeconds) * 100

## 5D. POMODORO TIMER LOGIC
States: WORK (25:00) → SHORT_BREAK (5:00) → WORK → ...
After 4 WORKs: LONG_BREAK (15:00)
pomodoroCount: int = 0  // completed work sessions today
onWorkTimerEnd:
pomodoroCount++
if pomodoroCount % 4 == 0: transition to LONG_BREAK
else: transition to SHORT_BREAK
send local notification: "🍅 Pomodoro complete! Time for a break."
play soft chime sound
onBreakTimerEnd:
transition to WORK
send local notification: "Break over — back to focus! 💪"
Focus tracking PAUSES during break periods.

## 5E. REAL-TIME FEEDBACK DISPLAY

Show feedback banner only if distracted for 3+ consecutive seconds:
  (avoids annoying micro-interruptions for brief glances)
  
Feedback priority hierarchy:
  1. "No face detected — are you still there?"
  2. "Eyes closed — stay awake!"
  3. "Looking away — stay focused!"
  4. "Looking up — keep your eyes on the screen"
  5. "Tilt your head straight"

After returning to focused state: 
  Show "Welcome back! 👋" for 2 seconds, then hide banner.

## 5F. STUDY SESSION SUMMARY

On session end, display and save to Firestore:
  - Total study time (HH:MM:SS)
  - Focus percentage (with comparison to user's weekly average)
  - Number of Pomodoros completed
  - Distraction count and distraction rate per hour
  - Longest uninterrupted focus streak (in minutes)
  - Distraction timeline graph (fl_chart — show focus vs distract over time)
  - Grade: 
      90–100% → "Deep Work Master 🧠"
      75–89%  → "Focused Learner 📚"
      60–74%  → "Keep Practicing ✏️"
      < 60%   → "Many Distractions 📵"

═══════════════════════════════════════════════════════════════════
PART 6 — AI ASSISTANT: FIREBASE FUNCTION FULL SPEC
═══════════════════════════════════════════════════════════════════

## Firebase Function: `getAIResponse` (TypeScript)
```typescript
import { onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";

const geminiKey = defineSecret("GEMINI_API_KEY");

export const getAIResponse = onCall(
  { secrets: [geminiKey] },
  async (request) => {
    const { message, uid } = request.data;
    
    // 1. Fetch last 10 sessions from Firestore
    const sessions = await admin.firestore()
      .collection("sessions")
      .where("uid", "==", uid)
      .orderBy("startedAt", "desc")
      .limit(10)
      .get();
    
    // 2. Build activity context string
    const context = sessions.docs.map(doc => {
      const d = doc.data();
      if (d.type === "exercise") {
        return `[${d.type}] ${d.metrics.exercise}: ${d.metrics.reps} reps, 
                posture score ${d.metrics.postureScore}/100`;
      } else if (d.type === "yoga") {
        return `[${d.type}] ${d.metrics.pose}: held ${d.metrics.holdDurationSec}s, 
                accuracy ${d.metrics.accuracyScore}%`;
      } else {
        return `[${d.type}] focus: ${d.metrics.focusPercent.toFixed(1)}%, 
                ${d.metrics.pomodorosCompleted} pomodoros`;
      }
    }).join("\n");

    // 3. Build system prompt with temporal awareness
    const systemPrompt = `You are Harmonia, a warm and encouraging AI wellness 
coach. You have access to the user's activity history for the past sessions. 
Use this to give highly personalized, specific advice. Never give medical advice.
Always be encouraging. Keep responses under 150 words unless a detailed workout 
plan is requested.

USER'S RECENT ACTIVITY:
${context || "No sessions recorded yet. Encourage them to try their first session!"}

Today's date: ${new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' })}`;

    // 4. Call Gemini API
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey.value()}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: [{ role: "user", parts: [{ text: message }] }],
          generationConfig: { maxOutputTokens: 300, temperature: 0.7 }
        })
      }
    );
    
    const data = await response.json();
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text ?? 
                  "I couldn't process that. Please try again.";
    
    // 5. Save to chat history
    await admin.firestore()
      .collection("chatHistory").doc(uid)
      .collection("messages").add({
        role: "assistant", content: reply, timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    
    return { reply };
  }
);
```

## AI Assistant UI Behavior

Quick prompt chips (pre-defined context-aware queries):
  After first load, analyze last session type and show relevant chips:
  - If last session was exercise: "How was my workout?" | "Suggest next exercise"
  - If last session was yoga: "Rate my yoga progress" | "Which pose should I master?"
  - If last session was focus: "How was my focus today?" | "Tips to stay focused longer"
  - Generic: "Give me a weekly summary" | "Create a workout plan for this week"

Response animation: 
  Stream text character by character using a ticker with 15ms delay per character.
  Show animated typing dots (3 dots, staggered opacity animation) while waiting.

═══════════════════════════════════════════════════════════════════
PART 7 — PERFORMANCE & ARCHITECTURE REQUIREMENTS
═══════════════════════════════════════════════════════════════════

## 7A. ISOLATE ARCHITECTURE (critical for 60fps UI)

All ML inference MUST run on a separate Dart isolate:
  - Camera frames → convert to InputImage → send to isolate via SendPort
  - Isolate runs MediaPipe/MLKit → sends back PoseLandmark list + computed angles
  - UI isolate only draws overlays and updates state — never blocks

Use compute() for one-off heavy computations (TFLite inference).
Use long-lived isolates (via Isolate.spawn) for the continuous camera pipeline.

## 7B. CAMERA PIPELINE
```dart
// Target 30fps for pose estimation
controller = CameraController(
  camera,
  ResolutionPreset.medium,  // 720p — balance quality vs performance
  enableAudio: false,
  imageFormatGroup: ImageFormatGroup.yuv420,  // most efficient for ML
);

// Process every 2nd frame (15fps effective) if device is low-end:
frameCount++;
if (frameCount % 2 != 0 && isLowEndDevice) return;
```

Detect low-end device: if totalRAM < 3GB, enable frame-skipping mode.

## 7C. CANVAS OVERLAY DRAWING

Draw skeleton overlay on CustomPainter:
  - Joints: filled circles, radius 6px, color based on visibility score
    visibility > 0.8 → green, 0.5–0.8 → yellow, < 0.5 → red
  - Bones: lines connecting landmark pairs, width 3px
  - Angle arcs: draw arc at vertex joint showing measured angle
  - Text: angle value displayed near joint in white with dark shadow

Landmark connection pairs to draw (the standard MediaPipe skeleton):
  [11,12], [11,13], [13,15], [12,14], [14,16],  // arms
  [11,23], [12,24], [23,24],                      // torso
  [23,25], [25,27], [27,29], [27,31],            // left leg
  [24,26], [26,28], [28,30], [28,32]             // right leg

## 7D. OFFLINE SUPPORT

Enable Firestore offline persistence:
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

Queue sessions locally when offline; sync when connectivity restored.
Show offline indicator badge in app bar when no internet.

═══════════════════════════════════════════════════════════════════
PART 8 — FIRESTORE SECURITY RULES
═══════════════════════════════════════════════════════════════════
rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {
function isAuth() { return request.auth != null; }
function isOwner(uid) { return request.auth.uid == uid; }

match /users/{uid} {
  allow read, write: if isAuth() && isOwner(uid);
}

match /sessions/{sessionId} {
  allow read: if isAuth() && resource.data.uid == request.auth.uid;
  allow create: if isAuth() && request.resource.data.uid == request.auth.uid;
  allow update, delete: if false;  // immutable sessions
}

match /chatHistory/{uid}/messages/{msgId} {
  allow read, write: if isAuth() && isOwner(uid);
}
}
}

═══════════════════════════════════════════════════════════════════
PART 9 — BUILD ORDER INSTRUCTIONS FOR COPILOT
═══════════════════════════════════════════════════════════════════

Build in this exact sequence:

PHASE 1 — FOUNDATION:
  1. pubspec.yaml with all dependencies
  2. Firebase setup (firebase_options.dart, main.dart initialization)
  3. Firestore security rules
  4. Core theme (Material 3, dark/light, color scheme)
  5. GoRouter setup with all 5 routes

PHASE 2 — AUTH:
  6. AuthRepository (email+password + Google Sign-In)
  7. AuthNotifier (Riverpod AsyncNotifier)
  8. LoginScreen + SignupScreen + OnboardingFlow (3 screens)

PHASE 3 — SHARED ML ENGINE:
  9. PoseService (Dart isolate, camera pipeline, landmark extraction)
  10. AngleCalculator utility class (all angle functions)
  11. SkeletonPainter (CustomPainter for overlay)

PHASE 4 — EXERCISE MODE:
  12. ExerciseConfig model (per-exercise landmarks, thresholds, feedback rules)
  13. ExerciseAnalyzer (all 10 exercises, rep counting, form scoring)
  14. ExerciseNotifier (Riverpod)
  15. ExerciseScreen + ExerciseSelectorSheet + SessionSummaryModal

PHASE 5 — YOGA MODE:
  16. YogaConfig model (all 15 poses, reference vectors, angle rules)
  17. YogaAnalyzer (accuracy scoring, stability, hold timer)
  18. TFLiteService (model loading + inference)
  19. YogaNotifier (Riverpod)
  20. YogaScreen + PoseGuideOverlay + AccuracyRingWidget

PHASE 6 — STUDY FOCUS:
  21. FaceAnalyzer (ML Kit integration, all 5 focus checks)
  22. PomodoroTimer (state machine)
  23. FocusNotifier (Riverpod)
  24. FocusScreen + PiPCameraView + FocusRingWidget + FocusTimelineChart

PHASE 7 — DASHBOARD:
  25. SessionRepository (Firestore CRUD)
  26. StatsNotifier (aggregation, charts data)
  27. DashboardScreen + all chart widgets

PHASE 8 — AI ASSISTANT:
  28. Firebase Functions (all 3 functions in TypeScript)
  29. ChatRepository (Firestore + Functions integration)
  30. AssistantNotifier (Riverpod)
  31. AssistantScreen + ChatBubble + TypingIndicator + QuickChipBar

PHASE 9 — SETTINGS & POLISH:
  32. SettingsScreen
  33. Lottie animations on session complete
  34. Shimmer loading states
  35. Error handling + SnackBar system
  36. flutter_tts integration (audio rep cues)
  37. flutter_local_notifications (Pomodoro alerts)

Start now. Generate Phase 1 completely, then proceed sequentially.
After each phase, confirm completion before moving to the next.