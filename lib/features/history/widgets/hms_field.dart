import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String normalizeHms(String raw) {
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return '00:00:00';
  final (hh, mm, ss) = _splitHms(d);
  return _pad(_capped(hh, 23), _capped(mm, 59), _capped(ss, 59));
}

(String, String, String) _splitHms(String d) {
  if (d.length <= 2) return (d.padLeft(2, '0'), '00', '00');
  if (d.length <= 4) {
    return (
      d.substring(0, d.length - 2).padLeft(2, '0'),
      d.substring(d.length - 2),
      '00',
    );
  }
  final six = d.length > 6 ? d.substring(d.length - 6) : d.padLeft(6, '0');
  return (six.substring(0, 2), six.substring(2, 4), six.substring(4, 6));
}

int _capped(String part, int max) {
  final value = int.tryParse(part) ?? 0;
  return value > max ? max : value;
}

String _pad(int h, int m, int s) =>
    [h, m, s].map((part) => part.toString().padLeft(2, '0')).join(':');

({int h, int m, int s})? parseHms(String value) {
  final m = RegExp(
    r'^(\d{2}):(\d{2}):(\d{2})$',
  ).firstMatch(normalizeHms(value));
  if (m == null) return null;
  return (
    h: int.parse(m.group(1)!),
    m: int.parse(m.group(2)!),
    s: int.parse(m.group(3)!),
  );
}

class _HmsAutoColonFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    const max = 6;
    final take = digits.length > max ? digits.substring(0, max) : digits;

    final buf = StringBuffer();
    for (int i = 0; i < take.length; i++) {
      if (i == 2 || i == 4) buf.write(':');
      buf.write(take[i]);
    }
    final formatted = buf.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class HmsField extends StatelessWidget {
  const HmsField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  void _normalizeNow() {
    final raw = controller.text.trim();
    if (raw.isEmpty) return;

    final normalized = normalizeHms(raw);
    controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      onSubmitted: (_) {
        _normalizeNow();
        onSubmitted?.call();
      },
      onEditingComplete: _normalizeNow,
      inputFormatters: [_HmsAutoColonFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
