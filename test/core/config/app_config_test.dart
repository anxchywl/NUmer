import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/config/app_config.dart';

AppConfig _config(Map<String, dynamic> module) => AppConfig.fromMap({
  'modules': {'gradus': module},
});

bool _visible(AppConfig config, {String uid = 'u1', int build = 10}) =>
    config.isModuleVisible('gradus', uid: uid, build: build);

void main() {
  test('null map gives defaults', () {
    final config = AppConfig.fromMap(null);

    expect(config.minSupportedBuild, 0);
    expect(config.modules, isEmpty);
    expect(_visible(config), isFalse);
  });

  test('a disabled module is not visible', () {
    final config = _config({
      'enabled': false,
      'rollout': 100,
      'allow': ['u1'],
    });

    expect(_visible(config), isFalse);
  });

  test('allow makes a module visible at rollout 0', () {
    final config = _config({
      'enabled': true,
      'rollout': 0,
      'allow': ['u1'],
    });

    expect(_visible(config), isTrue);
    expect(_visible(config, uid: 'u2'), isFalse);
  });

  test('rollout 100 makes a module visible to everyone', () {
    final config = _config({'enabled': true, 'rollout': 100});

    for (var i = 0; i < 200; i++) {
      expect(_visible(config, uid: 'user-$i'), isTrue);
    }
  });

  test('a partial rollout splits users by their hash', () {
    // stableHash('abc') % 100 is 31
    expect(
      _visible(_config({'enabled': true, 'rollout': 32}), uid: 'abc'),
      isTrue,
    );
    expect(
      _visible(_config({'enabled': true, 'rollout': 31}), uid: 'abc'),
      isFalse,
    );
  });

  test('minBuild above the build hides a module', () {
    final config = _config({'enabled': true, 'rollout': 100, 'minBuild': 11});

    expect(_visible(config), isFalse);
    expect(_visible(config, build: 11), isTrue);
  });

  test('a non int minSupportedBuild counts as 0 and keeps modules', () {
    final config = AppConfig.fromMap({
      'minSupportedBuild': '40',
      'modules': {
        'gradus': {'enabled': true, 'rollout': 100},
      },
    });

    expect(config.minSupportedBuild, 0);
    expect(_visible(config), isTrue);
  });

  test('a malformed module entry is dropped and the others are kept', () {
    final config = AppConfig.fromMap({
      'minSupportedBuild': 3,
      'modules': {
        'text': 'on',
        'enabled': {'enabled': 'yes'},
        'rollout': {'enabled': true, 'rollout': 50.5},
        'allow': {'enabled': true, 'allow': 'u1'},
        'minBuild': {'enabled': true, 'minBuild': '1'},
        'gradus': {'enabled': true},
      },
    });

    expect(config.modules.keys, ['gradus']);
    expect(config.minSupportedBuild, 3);
  });

  test('modules that are not a map are ignored', () {
    final config = AppConfig.fromMap({
      'minSupportedBuild': 3,
      'modules': ['gradus'],
    });

    expect(config.modules, isEmpty);
    expect(config.minSupportedBuild, 3);
  });

  test('missing module fields fail closed', () {
    final flag = _config({}).modules['gradus']!;

    expect(flag.enabled, isFalse);
    expect(flag.rollout, 0);
    expect(flag.allow, isEmpty);
    expect(flag.minBuild, 0);
  });

  test('rollout is clamped to 0..100', () {
    expect(_config({'rollout': -5}).modules['gradus']!.rollout, 0);
    expect(_config({'rollout': 500}).modules['gradus']!.rollout, 100);
  });

  test('allow keeps only strings', () {
    final config = _config({
      'allow': ['u1', 2, null, 'u2'],
    });

    expect(config.modules['gradus']!.allow, ['u1', 'u2']);
  });

  test('the cached json round trips', () {
    final config = AppConfig.fromMap({
      'minSupportedBuild': 7,
      'modules': {
        'gradus': {
          'enabled': true,
          'rollout': 20,
          'allow': ['u1'],
          'minBuild': 5,
        },
      },
    });

    expect(AppConfig.fromJson(config.toJson()).toJson(), config.toJson());
  });

  test('stableHash is 32 bit FNV-1a', () {
    expect(stableHash('abc'), 440920331);
  });
}
