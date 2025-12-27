import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HeatmapService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  HeatmapService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  
  
  Future<Map<DateTime, int>> fetchDailyTotals(
      DateTime start, DateTime end) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();

    try {
      final query = _firestore
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .where('startUtc', isGreaterThanOrEqualTo: startUtc)
          .where('startUtc', isLessThanOrEqualTo: endUtc);

      final snapshot = await query.get();
      final minutes = <DateTime, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final seconds = (data['seconds'] as num?)?.toInt() ?? 0;
        if (seconds <= 0) continue;

        
        
        final sUtc = (data['startUtc'] as Timestamp).toDate();
        final sLocal = sUtc.toLocal();
        final dayKey = DateTime(sLocal.year, sLocal.month, sLocal.day);

        final min = _toMinutes(seconds);
        minutes.update(dayKey, (v) => v + min, ifAbsent: () => min);
      }
      return minutes;
    } catch (e) {
      
      return {};
    }
  }

  int _toMinutes(int seconds) {
    if (seconds <= 0) return 0;
    
    return (seconds / 60).floor();
  }
}
