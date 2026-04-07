from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from tensorflow import keras
from tensorflow.keras import layers

BASE_DIR = Path(__file__).resolve().parent
LABELS_ROOT = BASE_DIR / '.context' / 'dataset' / 'POSTURE_DATASET' / 'labels'
MODEL_DIR = BASE_DIR / 'assets' / 'models'
TFLITE_OUTPUT = MODEL_DIR / 'posture_classifier.tflite'
LABELS_OUTPUT = MODEL_DIR / 'posture_classifier_labels.txt'

EPOCHS = int(__import__('os').environ.get('POSTURE_EPOCHS', '25'))
BATCH_SIZE = 32


def parse_label_file(path: Path):
    text = path.read_text(encoding='utf-8').strip()
    if not text:
        return None
    parts = text.split()
    if len(parts) < 17:
        return None

    floats = [float(p) for p in parts]
    # YOLO keypoint format: cls, cx, cy, w, h, then 4*(x,y,v)
    kpts = floats[5:17]
    if len(kpts) != 12:
        return None

    k0 = kpts[0:3]  # shoulder-left
    k1 = kpts[3:6]  # shoulder-right
    k2 = kpts[6:9]  # hip-left
    k3 = kpts[9:12]  # hip-right

    shoulder_mid_x = (k0[0] + k1[0]) / 2.0
    shoulder_mid_y = (k0[1] + k1[1]) / 2.0
    hip_mid_x = (k2[0] + k3[0]) / 2.0
    hip_mid_y = (k2[1] + k3[1]) / 2.0

    dx = abs(shoulder_mid_x - hip_mid_x)
    dy = abs(shoulder_mid_y - hip_mid_y)
    if dy < 1e-6:
        dy = 1e-6

    torso_tilt = dx / dy
    shoulder_tilt = abs(k0[1] - k1[1])

    # Pseudo-labeling from geometry: 1 = upright, 0 = slouched
    upright = (torso_tilt < 0.18) and (shoulder_tilt < 0.12)
    label = 1 if upright else 0

    feature = np.asarray(kpts, dtype=np.float32)
    return feature, label


def load_dataset(labels_root: Path):
    x_vals = []
    y_vals = []

    for split in ['train', 'val']:
        split_dir = labels_root / split
        if not split_dir.exists():
            continue
        for file in split_dir.glob('*.txt'):
            parsed = parse_label_file(file)
            if parsed is None:
                continue
            feat, label = parsed
            x_vals.append(feat)
            y_vals.append(label)

    x = np.asarray(x_vals, dtype=np.float32)
    y = np.asarray(y_vals, dtype=np.int64)
    return x, y


def build_model() -> keras.Model:
    inputs = keras.Input(shape=(12,))
    x = layers.Dense(64, activation='relu')(inputs)
    x = layers.Dropout(0.25)(x)
    x = layers.Dense(32, activation='relu')(x)
    outputs = layers.Dense(2, activation='softmax')(x)

    model = keras.Model(inputs, outputs, name='PostureClassifier')
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    return model


def export_tflite(keras_path: Path, tflite_path: Path):
    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    model = keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    tflite_path.write_bytes(tflite_model)
    LABELS_OUTPUT.write_text('slouched\nupright\n', encoding='utf-8')
    print(f'TFLite saved -> {tflite_path} ({len(tflite_model)/1024:.1f} KB)')
    print(f'Labels saved -> {LABELS_OUTPUT}')


if __name__ == '__main__':
    x, y = load_dataset(LABELS_ROOT)
    if len(x) == 0:
        raise RuntimeError('No posture label samples found.')

    print(f'Samples: {len(x)} | Upright: {(y == 1).sum()} | Slouched: {(y == 0).sum()}')

    x_train, x_val, y_train, y_val = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    model = build_model()
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(patience=8, restore_best_weights=True, monitor='val_accuracy'),
        keras.callbacks.ModelCheckpoint('PostureClassifier_best.keras', save_best_only=True, monitor='val_accuracy'),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=4, monitor='val_loss'),
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

    export_tflite(Path('PostureClassifier_best.keras'), TFLITE_OUTPUT)
