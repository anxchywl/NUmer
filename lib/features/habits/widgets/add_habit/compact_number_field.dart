import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'habit_input_decoration.dart';

class CompactNumberField extends StatelessWidget {
  final Key fieldKey;
  final double width;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const CompactNumberField({
    super.key,
    required this.fieldKey,
    required this.width,
    required this.focusNode,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: fieldKey,
        focusNode: focusNode,
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          FilteringTextInputFormatter.deny(RegExp(r'^0')),
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: habitInputDecoration(
          Theme.of(context),
          radius: 12,
          hintText: hintText,
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
