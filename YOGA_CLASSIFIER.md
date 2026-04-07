What This Repo Does Differently
The key insight — and why it's a published paper — is the skeletonization trick. Instead of feeding raw photos to the CNN, they first run MediaPipe and draw only the white skeleton dots/lines on a black canvas, then classify that. The results from the repo's paper:
ApproachBest Val AccuracyYogaConvo2d (raw images)89.97%YogaConvo2d (skeletonized)99.62%VGG16 (skeletonized)97.36%
The skeleton strips away clothing, lighting, skin tone, and background — the model only ever sees body geometry.

How to Run It
1. Get the dataset from Kaggle — 5 poses: downdog, goddess, tree, plank, warrior2.
2. Install dependencies:
bashpip install mediapipe tensorflow opencv-python scikit-learn matplotlib seaborn
3. Run the full pipeline:
bashpython yoga_pipeline.py
This will: skeletonize all images → train YogaConvo2d → plot accuracy/loss + confusion matrix → export yoga_classifier.tflite.

File Structure in the Repo

skeletonization.py — Stage 1: MediaPipe → black canvas with keypoint dots (I extended this to also draw skeleton connections using draw_landmarks, which looks better)
cnn-yoga.ipynb — Stage 2: CNN training, comparing YogaConvo2d vs VGG16, InceptionV3, InceptionResNetV2, NASNetMobile
models/ — pre-trained model weights
loss-metrics/ — saved training curves

You can swap build_yoga_conv2d() for build_vgg16() or build_inception_v3() in the script to replicate any row from the paper's results table.Yoga pipelinePY Download