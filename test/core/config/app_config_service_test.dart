import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/config/app_config.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFetch {
  Map<String, dynamic>? data;
  Exception? error;
  int calls = 0;

  Future<Map<String, dynamic>?> call() async {
    calls++;
    if (error case final error?) throw error;
    return data;
  }
}

Future<AppConfigService> _service(
  _FakeFetch fetch, {
  int? cachedMinimum,
}) async {
  SharedPreferences.setMockInitialValues({
    if (cachedMinimum != null)
      'app_config_v1': AppConfig(
        minSupportedBuild: cachedMinimum,
        modules: const {},
      ).toJson(),
  });
  return AppConfigService(
    prefs: await SharedPreferences.getInstance(),
    fetch: fetch.call,
    build: 10,
  );
}

void main() {
  test('starts from the cache without fetching', () async {
    final fetch = _FakeFetch();

    final service = await _service(fetch, cachedMinimum: 11);

    expect(service.config.minSupportedBuild, 11);
    expect(service.updateRequired, isTrue);
    expect(fetch.calls, 0);
  });

  test('a refresh caches the value for the next start', () async {
    final fetch = _FakeFetch()..data = {'minSupportedBuild': 4};
    final service = await _service(fetch);

    await service.refresh();
    final restarted = AppConfigService(
      prefs: await SharedPreferences.getInstance(),
      fetch: fetch.call,
      build: 10,
    );

    expect(restarted.config.minSupportedBuild, 4);
  });

  test('notifies only when the value changes', () async {
    final fetch = _FakeFetch()..data = {'minSupportedBuild': 4};
    final service = await _service(fetch);
    var notifications = 0;
    service.addListener(() => notifications++);

    await service.refresh();
    await service.refresh(force: true);

    expect(notifications, 1);
  });

  test('a missing document restores the defaults', () async {
    final service = await _service(_FakeFetch(), cachedMinimum: 11);

    await service.refresh();

    expect(service.config.minSupportedBuild, 0);
  });

  test('a FirebaseException keeps the value', () async {
    final fetch = _FakeFetch()
      ..error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    final service = await _service(fetch, cachedMinimum: 11);

    await service.refresh();

    expect(service.config.minSupportedBuild, 11);
  });

  test('a failed refresh does not delay the next one', () async {
    final fetch = _FakeFetch()
      ..error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    final service = await _service(fetch);

    await service.refresh();
    await service.refresh();

    expect(fetch.calls, 2);
  });

  test('other errors are not caught', () async {
    final fetch = _FakeFetch()..error = const FormatException();
    final service = await _service(fetch);

    await expectLater(service.refresh(), throwsFormatException);
  });

  test('refreshes again within 6 hours only when forced', () async {
    final fetch = _FakeFetch();
    final service = await _service(fetch);

    await service.refresh();
    await service.refresh();
    expect(fetch.calls, 1);

    await service.refresh(force: true);
    expect(fetch.calls, 2);
  });

  test('updateRequired flips when the minimum exceeds the build', () async {
    final fetch = _FakeFetch()..data = {'minSupportedBuild': 10};
    final service = await _service(fetch);

    await service.refresh();
    expect(service.updateRequired, isFalse);

    fetch.data = {'minSupportedBuild': 11};
    await service.refresh(force: true);
    expect(service.updateRequired, isTrue);
  });

  test('module visibility uses the app build', () async {
    final fetch = _FakeFetch()
      ..data = {
        'modules': {
          'gradus': {'enabled': true, 'rollout': 100, 'minBuild': 10},
          'clavis': {'enabled': true, 'rollout': 100, 'minBuild': 11},
        },
      };
    final service = await _service(fetch);

    await service.refresh();

    expect(service.isModuleVisible('gradus', 'u1'), isTrue);
    expect(service.isModuleVisible('clavis', 'u1'), isFalse);
  });
}
