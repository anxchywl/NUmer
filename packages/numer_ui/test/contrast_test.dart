import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _accentPresets = [
  0xFF448AFF,
  0xFF10B981,
  0xFF7C3AED,
  0xFFFF7F50,
  0xFFF43F5E,
];

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (max(a, b) + 0.05) / (min(a, b) + 0.05);
}

void main() {
  for (final preset in _accentPresets) {
    for (final brightness in Brightness.values) {
      final name = '${preset.toRadixString(16)} ${brightness.name}';

      test('contrast holds for $name', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: Color(preset),
          brightness: brightness,
        );
        final semantic = brightness == Brightness.dark
            ? NumerColors.dark
            : NumerColors.light;
        final surfaces = {
          'surface': scheme.surface,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };
        final texts = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'error': scheme.error,
          'success': semantic.success,
          'warning': semantic.warning,
        };

        for (final surface in surfaces.entries) {
          for (final text in texts.entries) {
            expect(
              _contrast(text.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '${text.key} on ${surface.key}',
            );
          }
        }
        expect(
          _contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(3),
          reason: 'primary on surface',
        );
      });
    }
  }
}
