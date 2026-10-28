import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class ModuleFlag {
  const ModuleFlag({
    required this.enabled,
    required this.rollout,
    required this.allow,
    required this.minBuild,
  });

  final bool enabled;
  final int rollout;
  final List<String> allow;
  final int minBuild;

  // missing fields fail closed, a wrong type drops the whole entry
  static ModuleFlag? _tryParse(Object? raw) {
    if (raw is! Map) return null;
    final enabled = raw['enabled'] ?? false;
    final rollout = raw['rollout'] ?? 0;
    final allow = raw['allow'] ?? const <Object?>[];
    final minBuild = raw['minBuild'] ?? 0;
    if (enabled is! bool || rollout is! int) return null;
    if (allow is! List || minBuild is! int) return null;
    return ModuleFlag(
      enabled: enabled,
      rollout: rollout.clamp(0, 100),
      allow: List.unmodifiable(allow.whereType<String>()),
      minBuild: minBuild,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'rollout': rollout,
    'allow': allow,
    'minBuild': minBuild,
  };
}

@immutable
class AppConfig {
  const AppConfig({required this.minSupportedBuild, required this.modules});

  static const defaults = AppConfig(minSupportedBuild: 0, modules: {});

  final int minSupportedBuild;
  final Map<String, ModuleFlag> modules;

  factory AppConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    final minSupportedBuild = map['minSupportedBuild'];
    final rawModules = map['modules'];
    final modules = <String, ModuleFlag>{};
    if (rawModules is Map) {
      for (final MapEntry(:key, :value) in rawModules.entries) {
        final flag = ModuleFlag._tryParse(value);
        if (key is String && flag != null) modules[key] = flag;
      }
    }
    return AppConfig(
      minSupportedBuild: minSupportedBuild is int ? minSupportedBuild : 0,
      modules: Map.unmodifiable(modules),
    );
  }

  factory AppConfig.fromJson(String source) =>
      AppConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode({
    'minSupportedBuild': minSupportedBuild,
    'modules': {
      for (final MapEntry(:key, :value) in modules.entries) key: value.toJson(),
    },
  });

  bool isModuleVisible(String id, {required String uid, required int build}) {
    final flag = modules[id];
    if (flag == null || !flag.enabled || build < flag.minBuild) return false;
    return flag.allow.contains(uid) || stableHash(uid) % 100 < flag.rollout;
  }
}

// 32-bit FNV-1a, String.hashCode is not stable across runs
int stableHash(String s) {
  var hash = 2166136261;
  for (final byte in utf8.encode(s)) {
    hash = ((hash ^ byte) * 16777619) & 0xFFFFFFFF;
  }
  return hash;
}
