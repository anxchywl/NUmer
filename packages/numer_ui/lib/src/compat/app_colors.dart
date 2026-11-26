import 'package:flutter/material.dart';

import '../tokens/numer_colors.dart';

const double _disabledAlpha = 0.38;

// the app_ui names, resolved to the host scheme for module code
final class AppColors {
  const AppColors._(this._scheme, this._numer);

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return AppColors._(theme.colorScheme, theme.extension<NumerColors>()!);
  }

  final ColorScheme _scheme;
  final NumerColors _numer;

  Color get primary => _scheme.primary;
  Color get primaryDark => _scheme.primary;
  Color get primaryAccentDark => _scheme.primary;
  Color get primaryLight => _scheme.primaryContainer;
  Color get primaryLightDark => _scheme.primaryContainer;
  Color get background => _scheme.surface;
  Color get surface => _scheme.surfaceContainerHighest;
  Color get surfaceDark => _scheme.surfaceContainerHighest;
  Color get fieldBackground => _scheme.surfaceContainerHighest;
  Color get serviceBackground => _scheme.surfaceContainerHighest;
  Color get balanceCardBackground => _scheme.surfaceContainerHighest;
  Color get textPrimary => _scheme.onSurface;
  Color get textPrimaryDark => _scheme.onSurface;
  Color get textColor => _scheme.onSurface;
  Color get textColorDark => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurfaceVariant;
  Color get iconGrey => _scheme.onSurfaceVariant;
  Color get textDisabled => _scheme.onSurface.withValues(alpha: _disabledAlpha);
  Color get borderGrey => _scheme.outlineVariant;
  Color get borderDark => _scheme.outlineVariant;
  Color get divider => _scheme.outlineVariant;
  Color get dividerColor => _scheme.outlineVariant;
  Color get success => _numer.success;
  Color get lightGreen => _numer.success;
  Color get warning => _numer.warning;
  Color get error => _scheme.error;
  Color get errorText => _scheme.error;
  Color get errorTextDark => _scheme.error;
  Color get info => _scheme.primary;
  Color get lightBlue => _scheme.primary;
  Color get socialTelegram => _scheme.primary;
  Color get grey => _scheme.onSurfaceVariant;
  Color get iconSecondary => _scheme.onSurfaceVariant;
  Color get iconPrimary => _scheme.onSurface;
  Color get iconDisabled => _scheme.onSurface.withValues(alpha: _disabledAlpha);
  Color get white => _scheme.onPrimary;
  Color get black => _scheme.onSurface;
  Color get lightGrey => _scheme.outlineVariant;
  Color get transparent => Colors.transparent;
  Color get orange => _numer.warning;
  Color get green => _numer.success;
  Color get blue => _scheme.primary;
  Color get blueLight => _scheme.primaryContainer;
  Color get infoLight => _scheme.primaryContainer;
  Color get errorLight => _scheme.errorContainer;
  Color get successLight => _scheme.surfaceContainerHighest;
  Color get warningLight => _scheme.surfaceContainerHighest;
  Color get socialWhatsapp => _scheme.onSurfaceVariant;
}
