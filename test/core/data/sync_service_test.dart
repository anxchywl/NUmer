import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/sync_service.dart';

class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _FakeDatabase implements LocalDatabase {
  @override
  Future<void> openForUser(String uid) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocument implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocument();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollection();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// keeps the real scheduling and replaces only the remote work
class _RecordingSyncService extends SyncService {
  _RecordingSyncService()
      : super(
          firestore: _FakeFirestore(),
          connectivity: _FakeConnectivity(),
          database: _FakeDatabase(),
        );

  final calls = <String>[];
  Completer<void>? pushGate;

  @override
  Future<void> pushDirty() async {
    calls.add('push');
    await pushGate?.future;
  }

  @override
  Future<int> pullSince({bool full = false}) async {
    calls.add(full ? 'full pull' : 'pull');
    lastPull = DateTime.now();
    return 0;
  }
}

void main() {
  late _RecordingSyncService service;

  setUp(() => service = _RecordingSyncService());

  Future<void> startReturningUser() async {
    await service.start(uid: 'user', deviceId: 'device');
    await pumpEventQueue();
  }

  Completer<void> holdNextPush() {
    service.calls.clear();
    return service.pushGate = Completer<void>();
  }

  test('a returning user pulls once on a cold start', () async {
    await startReturningUser();

    expect(service.calls, ['push', 'pull']);
  });

  test('a local change after the launch pull only pushes', () async {
    await startReturningUser();
    service.calls.clear();

    await service.pushNow();
    await service.syncNow();

    expect(service.calls, ['push', 'push']);
  });

  test('a full sync requested during a push runs after it', () async {
    await startReturningUser();
    final gate = holdNextPush();

    final push = service.pushNow();
    var synced = false;
    final sync = service.syncNow(full: true).then((_) => synced = true);
    await pumpEventQueue();
    expect(service.calls, ['push']);
    expect(synced, isFalse);

    gate.complete();
    await Future.wait([push, sync]);

    expect(service.calls, ['push', 'push', 'full pull']);
  });

  test('a push requested during a push completes after the rerun', () async {
    await startReturningUser();
    final gate = holdNextPush();

    final first = service.pushNow();
    var rerun = false;
    final second = service.pushNow().then((_) => rerun = true);
    await pumpEventQueue();
    expect(rerun, isFalse);

    gate.complete();
    await Future.wait([first, second]);

    expect(service.calls, ['push', 'push']);
  });

  test('stop drops the queued sync and releases its caller', () async {
    await startReturningUser();
    final gate = holdNextPush();

    final push = service.pushNow();
    final queued = service.syncNow(full: true);
    await service.stop();
    await queued;
    gate.complete();
    await push;

    expect(service.calls, ['push']);
  });
}
