import 'package:flutter/material.dart';

// rainbow swatch that opens the custom color dialog (or a caller-supplied picker)
class ColorPickerButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorPicked;
  final VoidCallback? onCustomTap;

  const ColorPickerButton({
    super.key,
    required this.color,
    required this.onColorPicked,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (onCustomTap != null) {
          onCustomTap!();
          return;
        }
        final picked = await showDialog<Color>(
          context: context,
          builder: (ctx) => _ColorPickerDialog(initial: color),
        );
        if (picked != null) onColorPicked(picked);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF5F6D),
              Color(0xFFFFA559),
              Color(0xFFF9D548),
              Color(0xFF4ADE80),
              Color(0xFF2DD4BF),
              Color(0xFF3B82F6),
              Color(0xFF6366F1),
              Color(0xFFEC4899),
              Color(0xFFFF5F6D),
            ],
          ),
          border: Border.all(width: 2, color: Colors.white),
        ),
        child: const Icon(Icons.edit, size: 16, color: Colors.white),
      ),
    );
  }
}

// saturation/value pad plus a hue slider for picking an arbitrary color
class CustomColorPicker extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onChanged;

  const CustomColorPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<CustomColorPicker> {
  late double _hue;
  late double _sat;
  late double _val;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1, _hue, _sat.clamp(0, 1), _val.clamp(0, 1)).toColor();

  @override
  Widget build(BuildContext context) {
    final pureHue = HSVColor.fromAHSV(1, _hue, 1, 1).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 150.0;

          return GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _sat = (details.localPosition.dx / width).clamp(0, 1);
                _val = (1 - details.localPosition.dy / height).clamp(0, 1);
              });
              widget.onChanged(_currentColor);
            },
            onPanDown: (details) {
              setState(() {
                _sat = (details.localPosition.dx / width).clamp(0, 1);
                _val = (1 - details.localPosition.dy / height).clamp(0, 1);
              });
              widget.onChanged(_currentColor);
            },
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.white, pureHue],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _sat * width - 10,
                    top: (1 - _val) * height - 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(blurRadius: 2, color: Colors.black26)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Slider(
          value: _hue,
          min: 0,
          max: 360,
          label: 'Hue',
          activeColor: pureHue,
          onChanged: (value) {
            setState(() => _hue = value);
            widget.onChanged(_currentColor);
          },
        ),
      ],
    );
  }
}

// dialog wrapper that holds a pending color and returns it only on confirm
class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom color'),
      content: CustomColorPicker(
        initial: widget.initial,
        onChanged: (c) => setState(() => _temp = c),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _temp),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
