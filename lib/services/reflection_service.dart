import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReflectionService {
  ReflectionService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> addReflection({
    required String courseId,
    required String comment,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (comment.trim().isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('reflections')
        .add({
      'courseId': courseId,
      'comment': comment.trim(),
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteReflectionsForCourse(String courseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('reflections')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
