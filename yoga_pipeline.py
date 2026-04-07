"""
Yoga Pose Classification + Skeletonization
==========================================
Based on: github.com/shub-garg/Yoga-Pose-Classification-and-Skeletonization
Paper:    Garg et al. (2023), Journal of Ambient Intelligence and Humanized Computing

Two-stage approach:
  Stage 1 — skeletonization.py  : MediaPipe draws keypoints on a BLACK canvas
                                   (removes background noise, boosts accuracy by ~10%)
  Stage 2 — cnn-yoga.ipynb      : Custom CNN (YogaConvo2d) or transfer learning
                                   on the skeletonized images

Dataset: https://www.kaggle.com/datasets/niharika41298/yoga-poses-dataset
  5 classes: downdog, goddess, tree, plank, warrior2

Install:
  pip install mediapipe tensorflow opencv-python scikit-learn matplotlib seaborn
"""

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 1 — SKELETONIZATION  (matches skeletonization.py from the repo)
# ─────────────────────────────────────────────────────────────────────────────

import cv2
import mediapipe as mp
import numpy as np
import os
import urllib.request

from sklearn.model_selection import train_test_split

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_DATA_DIR = os.path.join(BASE_DIR, ".context", "dataset", "DATASET")
SKEL_DATA_DIR = os.path.join(BASE_DIR, ".context", "dataset", "DATASET_skeleton")
MODEL_DIR = os.path.join(BASE_DIR, "assets", "models")
TFLITE_OUTPUT = os.path.join(MODEL_DIR, "yoga_classifier.tflite")
POSE_MODEL_DIR = os.path.join(BASE_DIR, ".context", "models")
POSE_MODEL_PATH = os.path.join(POSE_MODEL_DIR, "pose_landmarker_lite.task")
POSE_MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
    "pose_landmarker_lite/float16/latest/pose_landmarker_lite.task"
)

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode

def skeletonize_dataset(input_folder: str, output_folder: str):
    """
    For every image in input_folder:
      - Detect MediaPipe pose landmarks
      - Draw ONLY the keypoints (white dots) on a black canvas
      - Save to output_folder (preserving subfolder structure)

    This removes clothing, skin tone, and background — the CNN only
    sees body geometry. Boosts accuracy from ~89% → ~99% (per paper).
    """
    mp_pose = mp.solutions.pose
    mp_draw  = mp.solutions.drawing_utils
    pose     = mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5)

    os.makedirs(output_folder, exist_ok=True)

    for root, dirs, files in os.walk(input_folder):
        for filename in files:
            if not filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                continue

            image_path  = os.path.join(root, filename)
            # Mirror the subfolder structure in the output
            rel_path    = os.path.relpath(root, input_folder)
            out_dir     = os.path.join(output_folder, rel_path)
            os.makedirs(out_dir, exist_ok=True)
            output_path = os.path.join(out_dir, filename)

            image       = cv2.imread(image_path)
            if image is None:
                continue

            h, w, _    = image.shape
            image_rgb  = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            result     = pose.process(image_rgb)

            # Black canvas — only keypoints survive
            canvas     = np.zeros((h, w, 3), dtype=np.uint8)

            if result.pose_landmarks:
                # Draw skeleton connections
                mp_draw.draw_landmarks(
                    canvas,
                    result.pose_landmarks,
                    mp_pose.POSE_CONNECTIONS,
                    mp_draw.DrawingSpec(color=(255,255,255), thickness=2, circle_radius=3),
                    mp_draw.DrawingSpec(color=(200,200,200), thickness=2),
                )

            cv2.imwrite(output_path, canvas)

    pose.close()
    print(f"Skeletonization complete → {output_folder}")


# ─────────────────────────────────────────────────────────────────────────────
# STAGE 2 — YogaConvo2d  (custom CNN from the paper)
# ─────────────────────────────────────────────────────────────────────────────

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

IMG_SIZE   = (224, 224)   # resize all skeletonized images to this
BATCH_SIZE = 32
EPOCHS     = int(os.environ.get("YOGA_EPOCHS", "5"))
NUM_CLASSES = 5           # downdog, goddess, tree, plank, warrior2

# ── Data loaders ──────────────────────────────────────────────────────────────

def get_datasets(data_dir: str):
    """Load train/val split from a skeletonized folder."""
    train_ds = keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=0.2,
        subset="training",
        seed=42,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
    )
    val_ds = keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=0.2,
        subset="validation",
        seed=42,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
    )
    class_names = train_ds.class_names
    print("Classes:", class_names)

    AUTOTUNE = tf.data.AUTOTUNE
    train_ds = train_ds.cache().shuffle(1000).prefetch(AUTOTUNE)
    val_ds   = val_ds.cache().prefetch(AUTOTUNE)

    return train_ds, val_ds, class_names


# ── YogaConvo2d — the custom model from the paper ────────────────────────────

def build_yoga_conv2d(num_classes: int) -> keras.Model:
    """
    Custom CNN that the paper calls 'YogaConvo2d'.
    Achieved 99.62% val accuracy and 97.09% test accuracy with skeletonized input.
    Architecture: repeated Conv→BN→Pool blocks, then Dense head.
    """
    data_augmentation = keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.1),
        layers.RandomZoom(0.1),
    ], name="augmentation")

    inputs = keras.Input(shape=(*IMG_SIZE, 3))
    x = data_augmentation(inputs)
    x = layers.Rescaling(1.0 / 255)(x)           # normalize [0,255] → [0,1]

    # Block 1
    x = layers.Conv2D(32, 3, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D()(x)

    # Block 2
    x = layers.Conv2D(64, 3, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D()(x)

    # Block 3
    x = layers.Conv2D(128, 3, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D()(x)

    # Block 4
    x = layers.Conv2D(256, 3, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D()(x)

    # Head
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(512, activation="relu")(x)
    x = layers.Dropout(0.4)(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs, name="YogaConvo2d")
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


# ── Transfer learning alternatives (from the paper's comparison) ──────────────

def build_vgg16(num_classes: int) -> keras.Model:
    """VGG16 + MediaPipe → 97.36% val, 96.86% test (per paper)."""
    base = keras.applications.VGG16(include_top=False, weights="imagenet",
                                     input_shape=(*IMG_SIZE, 3))
    base.trainable = False  # freeze; fine-tune later if needed

    inputs = keras.Input(shape=(*IMG_SIZE, 3))
    x = keras.applications.vgg16.preprocess_input(inputs)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs, name="VGG16_yoga")
    model.compile(optimizer=keras.optimizers.Adam(1e-4),
                  loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    return model


def build_inception_v3(num_classes: int) -> keras.Model:
    """InceptionV3 + MediaPipe → 95.09% val, 94.39% test (per paper)."""
    base = keras.applications.InceptionV3(include_top=False, weights="imagenet",
                                           input_shape=(299, 299, 3))
    base.trainable = False

    inputs = keras.Input(shape=(299, 299, 3))
    x = keras.applications.inception_v3.preprocess_input(inputs)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs, name="InceptionV3_yoga")
    model.compile(optimizer=keras.optimizers.Adam(1e-4),
                  loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    return model


# ── Train ─────────────────────────────────────────────────────────────────────

def train_model(model: keras.Model, train_ds, val_ds, model_name: str):
    callbacks = [
        keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True,
                                       monitor="val_accuracy"),
        keras.callbacks.ModelCheckpoint(f"{model_name}_best.keras",
                                        save_best_only=True,
                                        monitor="val_accuracy"),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5,
                                           monitor="val_loss"),
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks,
    )
    return history


# ── Evaluate & plot ───────────────────────────────────────────────────────────

def plot_history(history, model_name: str):
    import matplotlib.pyplot as plt

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

    ax1.plot(history.history["accuracy"],     label="train")
    ax1.plot(history.history["val_accuracy"], label="val")
    ax1.set_title(f"{model_name} — Accuracy")
    ax1.set_xlabel("Epoch"); ax1.legend()

    ax2.plot(history.history["loss"],     label="train")
    ax2.plot(history.history["val_loss"], label="val")
    ax2.set_title(f"{model_name} — Loss")
    ax2.set_xlabel("Epoch"); ax2.legend()

    plt.tight_layout()
    plt.savefig(f"{model_name}_curves.png", dpi=150)
    plt.show()


def plot_confusion_matrix(model, val_ds, class_names: list, model_name: str):
    import matplotlib.pyplot as plt
    import seaborn as sns
    from sklearn.metrics import confusion_matrix

    y_true, y_pred = [], []
    for images, labels in val_ds:
        preds = model.predict(images, verbose=0)
        y_true.extend(labels.numpy())
        y_pred.extend(np.argmax(preds, axis=1))

    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt="d", xticklabels=class_names,
                yticklabels=class_names, cmap="Blues")
    plt.title(f"{model_name} — Confusion Matrix")
    plt.ylabel("True"); plt.xlabel("Predicted")
    plt.tight_layout()
    plt.savefig(f"{model_name}_confusion.png", dpi=150)
    plt.show()


# ── Export to TFLite ──────────────────────────────────────────────────────────

def export_tflite(keras_path: str, tflite_path: str, class_names: list):
    os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
    model     = keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    labels_path = tflite_path.replace(".tflite", "_labels.txt")
    open(labels_path, "w").write("\n".join(class_names))

    print(f"TFLite saved → {tflite_path}  ({len(tflite_model)/1024:.1f} KB)")
    print(f"Labels saved → {labels_path}")


# ── Landmark extraction for app-compatible training ──────────────────────────

def ensure_pose_model() -> str:
    os.makedirs(POSE_MODEL_DIR, exist_ok=True)
    if not os.path.exists(POSE_MODEL_PATH):
        print(f"Downloading pose landmarker model → {POSE_MODEL_PATH}")
        urllib.request.urlretrieve(POSE_MODEL_URL, POSE_MODEL_PATH)
    return POSE_MODEL_PATH


def _landmarks_to_feature_vector(landmarks) -> list[float]:
    points = [None] * 33
    for index, landmark in enumerate(landmarks):
        if index >= 33:
            break
        points[index] = landmark

    mid_hip_left = points[23]
    mid_hip_right = points[24]
    mid_shoulder_left = points[11]
    mid_shoulder_right = points[12]
    if not all([mid_hip_left, mid_hip_right, mid_shoulder_left, mid_shoulder_right]):
        return [0.0] * 99

    mid_hip_x = (mid_hip_left.x + mid_hip_right.x) / 2.0
    mid_hip_y = (mid_hip_left.y + mid_hip_right.y) / 2.0
    mid_hip_z = (mid_hip_left.z + mid_hip_right.z) / 2.0
    mid_shoulder_x = (mid_shoulder_left.x + mid_shoulder_right.x) / 2.0
    mid_shoulder_y = (mid_shoulder_left.y + mid_shoulder_right.y) / 2.0
    mid_shoulder_z = (mid_shoulder_left.z + mid_shoulder_right.z) / 2.0

    torso_dx = mid_shoulder_x - mid_hip_x
    torso_dy = mid_shoulder_y - mid_hip_y
    torso_dz = mid_shoulder_z - mid_hip_z
    torso_norm = float(np.sqrt(torso_dx**2 + torso_dy**2 + torso_dz**2))
    scale = torso_norm if torso_norm != 0 else 1.0

    feature_vector: list[float] = []
    for index in range(33):
        landmark = points[index]
        if landmark is None:
            feature_vector.extend([0.0, 0.0, 0.0])
            continue
        feature_vector.extend([
            (landmark.x - mid_hip_x) / scale,
            (landmark.y - mid_hip_y) / scale,
            (landmark.z - mid_hip_z) / scale,
        ])

    return feature_vector


def extract_landmark_dataset(image_dir: str, class_names: list[str], landmarker) -> tuple[np.ndarray, np.ndarray]:
    x_values: list[list[float]] = []
    y_values: list[int] = []
    skipped = 0

    for class_index, class_name in enumerate(class_names):
        class_dir = os.path.join(image_dir, class_name)
        if not os.path.isdir(class_dir):
            continue

        for filename in sorted(os.listdir(class_dir)):
            if not filename.lower().endswith((".jpg", ".jpeg", ".png", ".bmp", ".JPG")):
                continue

            image_path = os.path.join(class_dir, filename)
            try:
                image_bgr = cv2.imread(image_path, cv2.IMREAD_COLOR)
                if image_bgr is None:
                    skipped += 1
                    continue
                image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
                mp_image = mp.Image(
                    image_format=mp.ImageFormat.SRGB,
                    data=image_rgb,
                )
                result = landmarker.detect(mp_image)
            except Exception:
                skipped += 1
                continue

            if not result.pose_landmarks:
                skipped += 1
                continue

            feature_vector = _landmarks_to_feature_vector(result.pose_landmarks[0])
            x_values.append(feature_vector)
            y_values.append(class_index)

    print(f"Extracted {len(x_values)} samples from {image_dir}; skipped {skipped}")
    return np.asarray(x_values, dtype=np.float32), np.asarray(y_values, dtype=np.int64)


def build_landmark_classifier(num_classes: int) -> keras.Model:
    inputs = keras.Input(shape=(99,))
    x = layers.Dense(128, activation="relu")(inputs)
    x = layers.Dropout(0.25)(x)
    x = layers.Dense(64, activation="relu")(x)
    x = layers.Dropout(0.2)(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs, name="YogaLandmarkClassifier")
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def train_landmark_model(model: keras.Model, x_train, y_train, x_val, y_val, model_name: str):
    callbacks = [
        keras.callbacks.EarlyStopping(patience=8, restore_best_weights=True, monitor="val_accuracy"),
        keras.callbacks.ModelCheckpoint(f"{model_name}_best.keras", save_best_only=True, monitor="val_accuracy"),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=4, monitor="val_loss"),
    ]

    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=EPOCHS,
        batch_size=32,
        callbacks=callbacks,
        verbose=1,
    )
    return history


# ── Inference on a single image ───────────────────────────────────────────────

def predict_single(image_path: str, tflite_path: str, labels_path: str):
    """
    Full inference pipeline on a RAW (non-skeletonized) image:
      raw image → MediaPipe skeleton → TFLite CNN → pose label
    """
    class_names = open(labels_path).read().strip().split("\n")

    # Skeletonize on-the-fly
    mp_pose = mp.solutions.pose
    mp_draw  = mp.solutions.drawing_utils

    img     = cv2.imread(image_path)
    h, w, _ = img.shape
    rgb     = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    with mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5) as pose:
        result = pose.process(rgb)

    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    if result.pose_landmarks:
        mp_draw.draw_landmarks(canvas, result.pose_landmarks,
                               mp_pose.POSE_CONNECTIONS,
                               mp_draw.DrawingSpec(color=(255,255,255), thickness=2, circle_radius=3),
                               mp_draw.DrawingSpec(color=(200,200,200), thickness=2))
    else:
        print("No pose detected in image.")
        return None

    # Resize and normalize
    canvas_resized = cv2.resize(canvas, IMG_SIZE)
    tensor = canvas_resized.astype(np.float32)[np.newaxis, ...]   # (1,224,224,3)

    # TFLite inference
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]

    interpreter.set_tensor(inp["index"], tensor)
    interpreter.invoke()
    scores = interpreter.get_tensor(out["index"])[0]

    idx       = np.argmax(scores)
    pose_name = class_names[idx]
    conf      = scores[idx]

    print(f"Predicted: {pose_name}  ({conf:.1%} confidence)")
    return pose_name


# ─────────────────────────────────────────────────────────────────────────────
# MAIN — run everything end to end
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":

    MODEL_NAME    = "YogaConvo2d"

    pose_model_path = ensure_pose_model()

    print("── Stage 1: Loading labels ──────────────────────────────────")
    class_names = sorted(
        entry.name for entry in os.scandir(os.path.join(RAW_DATA_DIR, "TRAIN")) if entry.is_dir()
    )
    print("Classes:", class_names)

    print("\n── Stage 2: Extracting landmarks ───────────────────────────")
    landmarker_options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=pose_model_path),
        running_mode=VisionRunningMode.IMAGE,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    with PoseLandmarker.create_from_options(landmarker_options) as landmarker:
        x_train_all, y_train_all = extract_landmark_dataset(
            os.path.join(RAW_DATA_DIR, "TRAIN"), class_names, landmarker
        )
        x_test, y_test = extract_landmark_dataset(
            os.path.join(RAW_DATA_DIR, "TEST"), class_names, landmarker
        )

    x_train, x_val, y_train, y_val = train_test_split(
        x_train_all,
        y_train_all,
        test_size=0.2,
        random_state=42,
        stratify=y_train_all,
    )

    print("\n── Stage 3: Building model ──────────────────────────────────")
    model = build_landmark_classifier(num_classes=len(class_names))
    model.summary()

    print("\n── Stage 4: Training ────────────────────────────────────────")
    history = train_landmark_model(model, x_train, y_train, x_val, y_val, MODEL_NAME)

    if os.environ.get("YOGA_PLOT_RESULTS", "0") == "1":
        plot_history(history, MODEL_NAME)
        val_dataset = tf.data.Dataset.from_tensor_slices((x_val, y_val)).batch(32)
        plot_confusion_matrix(model, val_dataset, class_names, MODEL_NAME)

    print("\n── Stage 5: Evaluating ─────────────────────────────────────")
    test_loss, test_accuracy = model.evaluate(x_test, y_test, verbose=0)
    print(f"Test accuracy: {test_accuracy:.4f} | Test loss: {test_loss:.4f}")

    print("\n── Stage 6: Exporting TFLite ────────────────────────────────")
    export_tflite(f"{MODEL_NAME}_best.keras", TFLITE_OUTPUT, class_names)

    # predict_single("test.jpg", TFLITE_OUTPUT, TFLITE_OUTPUT.replace('.tflite', '_labels.txt'))
