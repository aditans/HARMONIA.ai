import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const FirebaseOptions(
          apiKey: 'AIzaSyB9qgk4fSmbk5DOWwF7gDMgK66h6mb-wDw',
          appId: '1:1040765054234:android:1914f465a917c5bcccd0a3',
          messagingSenderId: '1040765054234',
          projectId: 'harmonia-daccb',
          storageBucket: 'harmonia-daccb.firebasestorage.app',
        );
    }
  }
}
