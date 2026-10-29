import 'dart:async';

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
      retryOnError(() => _doc(uid).snapshots().map(_fromSnapshot));

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

// reads are denied until the server indexes a new membership, so open again
Stream<T> retryOnError<T>(
  Stream<T> Function() open, {
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(minutes: 1),
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? retry;
  var delay = initialDelay;

  void listen() {
    subscription = open().listen(
      (value) {
        delay = initialDelay;
        controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        controller.addError(error, stackTrace);
        subscription?.cancel();
        retry = Timer(delay, listen);
        final next = delay * 2;
        delay = next < maxDelay ? next : maxDelay;
      },
      onDone: controller.close,
    );
  }

  controller = StreamController<T>(
    onListen: listen,
    onCancel: () {
      retry?.cancel();
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
