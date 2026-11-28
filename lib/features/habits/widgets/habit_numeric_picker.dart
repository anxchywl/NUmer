import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HabitNumericPicker extends StatelessWidget {
  const HabitNumericPicker({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.locked,
    required this.hideSteps,
    required this.maxValue,
    required this.onStepStart,
    required this.onStepStop,
    this.unit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  // an exact target cannot be typed or stepped
  final bool locked;
  final bool hideSteps;
  final double maxValue;
  final ValueChanged<double> onStepStart;
  final VoidCallback onStepStop;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = !locked && !hideSteps;
    final unit = this.unit;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Visibility(
          visible: steps,
          child: _stepButton(theme, Icons.remove, -1.0),
        ),
        const SizedBox(width: 24),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              child: locked ? _lockedValue(theme) : _field(theme),
            ),
            if (unit != null && unit.isNotEmpty)
              Text(
                unit,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(width: 24),
        Visibility(visible: steps, child: _stepButton(theme, Icons.add, 1.0)),
      ],
    );
  }

  Widget _lockedValue(ThemeData theme) {
    return Center(
      child: Text(
        controller.text,
        style: theme.textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.bold,
          // dimmed to show locked
          color: theme.colorScheme.onSurface.withAlpha(128),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _field(ThemeData theme) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: theme.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
        height: 1.1,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        MaxValueFormatter(maxValue),
      ],
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _stepButton(ThemeData theme, IconData icon, double step) {
    return GestureDetector(
      onTapDown: (_) {
        onStepStart(step);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => onStepStop(),
      onTapCancel: onStepStop,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}

class MaxValueFormatter extends TextInputFormatter {
  final double max;
  MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final val = double.tryParse(newValue.text);
    if (val == null) return oldValue;
    if (val > max) {
      return TextEditingValue(
        text: max.toInt().toString(),
        selection: TextSelection.collapsed(
          offset: max.toInt().toString().length,
        ),
      );
    }
    return newValue;
  }
}
