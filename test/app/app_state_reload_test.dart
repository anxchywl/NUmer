import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';

class _FakeSyncService implements SyncService {
  late Future<void> Function() finishPull;

  @override
  Future<void> Function()? onBeforeStop;

  @override
  void addAfterPullListener(Future<void> Function() listener) {
    finishPull = listener;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// reads storage when a load starts and applies it only when the test lets it end
class _FakeLoader {
  var stored = 'before pull';
  String? applied;
  final forced = <bool>[];
  final _gates = <Completer<void>>[];

  Future<void> load({required bool force}) async {
    final read = stored;
    forced.add(force);
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    applied = read;
  }

  Future<void> finishLoad() async {
    _gates.last.complete();
    await pumpEventQueue();
  }
}

void main() {
  late _FakeLoader loader;
  late _FakeSyncService sync;
  late AppState state;

  setUp(() {
    loader = _FakeLoader();
    sync = _FakeSyncService();
    state = AppState(loadOverride: loader.load)..bindSyncService(sync);
  });

  test(
    'a pull that ends during the first load is read by a second one',
    () async {
      unawaited(state.load());
      loader.stored = 'after pull';
      var refreshed = false;
      unawaited(sync.finishPull().then((_) => refreshed = true));
      await pumpEventQueue();
      expect(loader.forced, [false]);

      await loader.finishLoad();
      expect(loader.forced, [false, true]);
      expect(refreshed, isFalse);

      await loader.finishLoad();
      expect(loader.applied, 'after pull');
      expect(refreshed, isTrue);
    },
  );

  test('refreshes during one load share a single rerun', () async {
    unawaited(state.load());
    unawaited(sync.finishPull());
    unawaited(sync.finishPull());

    await loader.finishLoad();
    await loader.finishLoad();

    expect(loader.forced, [false, true]);
  });

  test('a refresh during the rerun reads storage once more', () async {
    unawaited(state.load());
    unawaited(sync.finishPull());
    await loader.finishLoad();

    loader.stored = 'second pull';
    unawaited(sync.finishPull());
    await loader.finishLoad();
    await loader.finishLoad();

    expect(loader.forced, [false, true, true]);
    expect(loader.applied, 'second pull');
  });

  test('a plain load during a load does not rerun it', () async {
    unawaited(state.load());
    unawaited(state.load());

    await loader.finishLoad();

    expect(loader.forced, [false]);
  });

  test('unload drops the queued rerun', () async {
    unawaited(state.load());
    unawaited(sync.finishPull());
    state.unload();

    await loader.finishLoad();

    expect(loader.forced, [false]);
  });
}
