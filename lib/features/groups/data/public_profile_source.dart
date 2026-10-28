import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:numer_app/features/groups/models/public_profile.dart';

// null means the profile document does not exist
abstract class PublicProfileSource {
  Stream<PublicProfile?> watch(String uid);

  Future<PublicProfile?> fetch(String uid);
}

class FirestorePublicProfileSource implements PublicProfileSource {
  FirestorePublicProfileSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<PublicProfile?> watch(String uid) =>
      _doc(uid).snapshots().map(_fromSnapshot);

  @override
  Future<PublicProfile?> fetch(String uid) async =>
      _fromSnapshot(await _doc(uid).get());

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('publicProfiles').doc(uid);

  PublicProfile? _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    return data == null ? null : PublicProfile.fromMap(snap.id, data);
  }
}
