import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: email,
            password: password,
          );
    });
  }

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final UserCredential credential = await ref.read(firebaseAuthProvider).createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
      await credential.user?.updateDisplayName(displayName);
      await ref.read(firestoreProvider).collection('users').doc(credential.user!.uid).set({
        'displayName': displayName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'streakDays': 0,
        'totalSessions': 0,
      }, SetOptions(merge: true));
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final GoogleSignInAccount? account = await GoogleSignIn(scopes: ['email', 'profile']).signIn();
      if (account == null) {
        throw FirebaseAuthException(code: 'canceled', message: 'Google sign-in was cancelled.');
      }
      
      final GoogleSignInAuthentication auth = await account.authentication;
      
      // Check for null tokens
      if (auth.accessToken == null && auth.idToken == null) {
        throw FirebaseAuthException(
          code: 'invalid_credential',
          message: 'Failed to get Google authentication tokens.',
        );
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      
      final UserCredential userCredential = await ref.read(firebaseAuthProvider).signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        final displayName = user.displayName ?? account.displayName ?? 'Harmonia User';
        final photoURL = user.photoURL ?? account.photoUrl;
        
        await user.updateDisplayName(displayName);
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        
        await ref.read(firestoreProvider).collection('users').doc(user.uid).set({
          'displayName': displayName,
          'email': user.email ?? account.email,
          'photoURL': photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'streakDays': 0,
          'totalSessions': 0,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
    await GoogleSignIn().signOut();
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);
