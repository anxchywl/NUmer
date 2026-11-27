import 'package:flutter/material.dart';

import '../components/numer_button_child.dart';
import 'app_icon.dart';
import 'app_icons.dart';
import 'app_spacing.dart';

// every size is drawn 48 high, the names remain so module code compiles
enum AppButtonSize { small, medium, large }

enum AppIconButtonSize {
  small(AppSpacing.iconSm),
  medium(AppSpacing.iconMd),
  large(AppSpacing.iconDf);

  const AppIconButtonSize(this._iconSize);

  final double _iconSize;
}

abstract class _AppButton extends StatelessWidget {
  const _AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingHint,
    this.isEnabled = true,
    this.icon,
    this.width,
    this.size = AppButtonSize.large,
    this.destructive = false,
  }) : assert(
         !isLoading || loadingHint != null,
         'say what a screen reader hears',
       );

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  // the caller's localized word for a screen reader, this package has none
  final String? loadingHint;
  final bool isEnabled;
  final Widget? icon;
  final double? width;
  final AppButtonSize size;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _button(
        Theme.of(context).colorScheme,
        isEnabled && !isLoading ? onPressed : null,
        _child(),
      ),
    );
  }

  Widget _button(ColorScheme scheme, VoidCallback? onPressed, Widget child);

  Widget _child() {
    return NumerButtonChild(
      label: text,
      loading: isLoading,
      loadingHint: loadingHint,
      icon: icon,
    );
  }
}

class AppPrimaryButton extends _AppButton {
  const AppPrimaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.loadingHint,
    super.isEnabled,
    super.icon,
    super.width,
    super.size,
    super.destructive,
  });

  @override
  Widget _button(ColorScheme scheme, VoidCallback? onPressed, Widget child) {
    return FilledButton(
      onPressed: onPressed,
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null,
      child: child,
    );
  }
}

class AppSecondaryButton extends _AppButton {
  const AppSecondaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.loadingHint,
    super.isEnabled,
    super.icon,
    super.width,
    super.size,
    super.destructive,
  });

  @override
  Widget _button(ColorScheme scheme, VoidCallback? onPressed, Widget child) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: destructive
          ? FilledButton.styleFrom(foregroundColor: scheme.error)
          : null,
      child: child,
    );
  }
}

class AppTextButton extends _AppButton {
  const AppTextButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.loadingHint,
    super.isEnabled,
    super.icon,
    super.width,
    super.size,
    super.destructive,
  });

  @override
  Widget _button(ColorScheme scheme, VoidCallback? onPressed, Widget child) {
    return TextButton(
      onPressed: onPressed,
      style: destructive
          ? TextButton.styleFrom(foregroundColor: scheme.error)
          : null,
      child: child,
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AppIconButtonSize.medium,
  });

  final AppIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonSize size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AppIcon(icon, size: size._iconSize),
    );
  }
}
