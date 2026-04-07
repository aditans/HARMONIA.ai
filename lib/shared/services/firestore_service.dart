import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> sessionsCollection() {
    return _db.collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> usersCollection() {
    return _db.collection('users');
  }
}
