import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icon.dart';
import 'app_icons.dart';
import 'app_spacing.dart';
import 'single_space_formatter.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.trimSpaces = true,
    this.contentPadding,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool trimSpaces;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: _decoration(),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      validator: validator,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: [
        ...?inputFormatters,
        if (trimSpaces) SingleSpaceFormatter(),
      ],
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      helperText: helperText,
      counterText: '',
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: contentPadding,
    );
  }
}

class GlobalSearchBar extends StatelessWidget {
  const GlobalSearchBar({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.showFilterButton = false,
    this.onFilterPressed,
    this.inputFormatters,
    this.maxLength,
    this.clearTooltip,
    this.filterTooltip,
  }) : assert(
         controller == null || clearTooltip != null,
         'the clear button needs a tooltip',
       ),
       assert(
         !showFilterButton || filterTooltip != null,
         'the filter button needs a tooltip',
       );

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool showFilterButton;
  final VoidCallback? onFilterPressed;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? clearTooltip;
  final String? filterTooltip;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: const AppIcon(AppIcons.search, size: AppSpacing.iconMd),
        suffixIcon: _actions(),
      ),
    );
  }

  Widget? _actions() {
    final controller = this.controller;
    if (controller == null && !showFilterButton) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller != null) _clearButton(controller),
        if (showFilterButton)
          IconButton(
            tooltip: filterTooltip,
            onPressed: onFilterPressed,
            icon: const AppIcon(AppIcons.filter, size: AppSpacing.iconMd),
          ),
      ],
    );
  }

  Widget _clearButton(TextEditingController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: clearTooltip,
          onPressed: () {
            controller.clear();
            onClear?.call();
          },
          icon: const AppIcon(AppIcons.close, size: AppSpacing.iconMd),
        );
      },
    );
  }
}
