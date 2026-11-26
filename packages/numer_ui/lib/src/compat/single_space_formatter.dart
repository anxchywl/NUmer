import 'dart:math';

import 'package:flutter/services.dart';

// drops leading and doubled spaces as they are typed, as app_ui fields did
class SingleSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trimLeft().replaceAll(RegExp(' {2,}'), ' ');
    if (text == newValue.text) return newValue;

    final removed = newValue.text.length - text.length;
    final cursor = min(max(newValue.selection.end - removed, 0), text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
