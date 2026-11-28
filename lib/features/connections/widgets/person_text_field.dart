import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

class PersonTextField extends StatelessWidget {
  const PersonTextField({
    super.key,
    required this.focus,
    required this.id,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
    this.next,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.extraFormatters = const [],
    this.validator,
  });

  final NumerSheetFocusMode focus;
  final String id;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;

  // the field the keyboard moves to, null on the last one
  final String? next;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final List<TextInputFormatter> extraFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final multiline = maxLines > 1;
    return NumerFocusFold(
      hidden: focus.hides(id),
      child: TextFormField(
        controller: controller,
        focusNode: focus.nodeFor(id),
        textInputAction: multiline
            ? null
            : (next == null ? TextInputAction.done : TextInputAction.next),
        onFieldSubmitted: next == null ? null : (_) => focus.moveTo(next),
        decoration: _decoration(Theme.of(context)),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLength),
          ...extraFormatters,
        ],
      ),
    );
  }

  InputDecoration _decoration(ThemeData theme) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(
        BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: _border(
        BorderSide(color: theme.colorScheme.error, width: 1),
      ),
      focusedErrorBorder: _border(
        BorderSide(color: theme.colorScheme.error, width: 2),
      ),
    );
  }

  OutlineInputBorder _border([BorderSide side = BorderSide.none]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: side,
    );
  }
}
