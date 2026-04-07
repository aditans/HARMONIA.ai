import os
import urllib.request
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from tensorflow import keras
from tensorflow.keras import layers

BASE_DIR = Path(__file__).resolve().parent
DATASET_DIR = BASE_DIR / '.context' / 'dataset' / 'EXERCISE_DATASET' / 'DATASET'
MODEL_DIR = BASE_DIR / 'assets' / 'models'
TFLITE_OUTPUT = MODEL_DIR / 'exercise_classifier.tflite'
LABELS_OUTPUT = MODEL_DIR / 'exercise_classifier_labels.txt'
POSE_MODEL_DIR = BASE_DIR / '.context' / 'models'
POSE_MODEL_PATH = POSE_MODEL_DIR / 'pose_landmarker_lite.task'
POSE_MODEL_URL = (
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/'
    'pose_landmarker_lite/float16/latest/pose_landmarker_lite.task'
)

EPOCHS = int(os.environ.get('EXERCISE_EPOCHS', '6'))
BATCH_SIZE = 32

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode


def ensure_pose_model() -> str:
    POSE_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    if not POSE_MODEL_PATH.exists():
        print(f'Downloading pose landmarker model -> {POSE_MODEL_PATH}')
        urllib.request.urlretrieve(POSE_MODEL_URL, POSE_MODEL_PATH)
    return str(POSE_MODEL_PATH)


def landmarks_to_vector(landmarks) -> list[float]:
    points = [None] * 33
    for idx, lm in enumerate(landmarks):
        if idx < 33:
            points[idx] = lm

    left_hip = points[23]
    right_hip = points[24]
    left_shoulder = points[11]
    right_shoulder = points[12]
    if not all([left_hip, right_hip, left_shoulder, right_shoulder]):
        return [0.0] * 99

    mid_hip_x = (left_hip.x + right_hip.x) / 2.0
    mid_hip_y = (left_hip.y + right_hip.y) / 2.0
    mid_hip_z = (left_hip.z + right_hip.z) / 2.0
    mid_shoulder_x = (left_shoulder.x + right_shoulder.x) / 2.0
    mid_shoulder_y = (left_shoulder.y + right_shoulder.y) / 2.0
    mid_shoulder_z = (left_shoulder.z + right_shoulder.z) / 2.0

    torso_norm = float(
        np.sqrt(
            (mid_shoulder_x - mid_hip_x) ** 2
            + (mid_shoulder_y - mid_hip_y) ** 2
            + (mid_shoulder_z - mid_hip_z) ** 2
        )
    )
    scale = torso_norm if torso_norm != 0 else 1.0

    out = []
    for i in range(33):
        lm = points[i]
        if lm is None:
            out.extend([0.0, 0.0, 0.0])
        else:
            out.extend([
                (lm.x - mid_hip_x) / scale,
                (lm.y - mid_hip_y) / scale,
                (lm.z - mid_hip_z) / scale,
            ])
    return out


def extract_dataset(dataset_dir: Path, class_names: list[str], landmarker) -> tuple[np.ndarray, np.ndarray]:
    x_vals: list[list[float]] = []
    y_vals: list[int] = []
    skipped = 0

    for class_idx, class_name in enumerate(class_names):
        class_dir = dataset_dir / class_name
        if not class_dir.is_dir():
            continue

        for filename in sorted(class_dir.iterdir()):
            if filename.suffix.lower() not in {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}:
                continue
            try:
                image_bgr = cv2.imread(str(filename), cv2.IMREAD_COLOR)
                if image_bgr is None:
                    skipped += 1
                    continue
                image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
                result = landmarker.detect(mp_image)
                if not result.pose_landmarks:
                    skipped += 1
                    continue
                x_vals.append(landmarks_to_vector(result.pose_landmarks[0]))
                y_vals.append(class_idx)
            except Exception:
                skipped += 1

    print(f'Extracted {len(x_vals)} samples; skipped {skipped}')
    return np.asarray(x_vals, dtype=np.float32), np.asarray(y_vals, dtype=np.int64)


def build_model(num_classes: int) -> keras.Model:
    inputs = keras.Input(shape=(99,))
    x = layers.Dense(256, activation='relu')(inputs)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.25)(x)
    x = layers.Dense(64, activation='relu')(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)

    model = keras.Model(inputs, outputs, name='ExerciseLandmarkClassifier')
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    return model


def export_tflite(keras_path: Path, tflite_path: Path, class_names: list[str]):
    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    model = keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    tflite_path.write_bytes(tflite_model)
    LABELS_OUTPUT.write_text('\n'.join(class_names), encoding='utf-8')
    print(f'TFLite saved -> {tflite_path} ({len(tflite_model)/1024:.1f} KB)')
    print(f'Labels saved -> {LABELS_OUTPUT}')


if __name__ == '__main__':
    if not DATASET_DIR.exists():
        raise FileNotFoundError(f'Dataset not found: {DATASET_DIR}')

    class_names = sorted([p.name for p in DATASET_DIR.iterdir() if p.is_dir()])
    print('Classes:', class_names)

    pose_model_path = ensure_pose_model()
    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=pose_model_path),
        running_mode=VisionRunningMode.IMAGE,
        num_poses=1,
    )

    with PoseLandmarker.create_from_options(options) as landmarker:
        x_all, y_all = extract_dataset(DATASET_DIR, class_names, landmarker)

    x_train, x_val, y_train, y_val = train_test_split(
        x_all,
        y_all,
        test_size=0.2,
        random_state=42,
        stratify=y_all,
    )

    model = build_model(num_classes=len(class_names))
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(patience=6, restore_best_weights=True, monitor='val_accuracy'),
        keras.callbacks.ModelCheckpoint('ExerciseClassifier_best.keras', save_best_only=True, monitor='val_accuracy'),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3, monitor='val_loss'),
    ]

    model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=1,
    )

    val_loss, val_acc = model.evaluate(x_val, y_val, verbose=0)
    print(f'Validation accuracy: {val_acc:.4f} | Validation loss: {val_loss:.4f}')

    export_tflite(Path('ExerciseClassifier_best.keras'), TFLITE_OUTPUT, class_names)
