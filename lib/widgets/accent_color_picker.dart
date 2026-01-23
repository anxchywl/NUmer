import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n/app_localizations.dart';

class AccentColorPicker extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onSave;

  const AccentColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onSave,
  });

  @override
  State<AccentColorPicker> createState() => _AccentColorPickerState();
}

class _AccentColorPickerState extends State<AccentColorPicker> {
  late HSVColor _hsvColor;
  bool _namingMode = false;
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.currentColor);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AccentColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentColor != oldWidget.currentColor) {
      _hsvColor = HSVColor.fromColor(widget.currentColor);
    }
  }

  void _updateColor(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
    });
    widget.onColorChanged(hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context)!;

    // Base Presets
    final presets = [
      (const Color(0xFF6366F1), l10n.defaultPreset),
      (const Color(0xFF10B981), l10n.emeraldPreset),
      (const Color(0xFF7C3AED), l10n.indigoPreset),
      (const Color(0xFFFF7F50), l10n.coralPreset),
      (const Color(0xFFF43F5E), l10n.rosePreset),
    ];

    final appState = context.watch<AppState>();
    final userPresets = appState.userColorPresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOutCubic,
          crossFadeState: _namingMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          secondChild: const SizedBox(width: double.infinity),
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Preview Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.preview,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.currentColor,
                            foregroundColor: ThemeData.estimateBrightnessForColor(widget.currentColor) == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          child: const Text('Button'),
                        ),
                        const SizedBox(width: 12),
                        _PreviewSwitch(activeColor: widget.currentColor),
                        const SizedBox(width: 12),
                        Text(
                          l10n.textExample,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.currentColor,
                            decoration: TextDecoration.underline,
                            decorationColor: widget.currentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.6,
                      color: widget.currentColor,
                      backgroundColor: widget.currentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
 
        // Sliders
        Text(
          l10n.customColor,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(l10n.hue),
            Expanded(
              child: Slider(
                value: _hsvColor.hue,
                min: 0,
                max: 360,
                onChanged: (v) => _updateColor(_hsvColor.withHue(v)),
                activeColor: HSVColor.fromAHSV(1, _hsvColor.hue, 1, 1).toColor(),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(l10n.saturation),
            Expanded(
              child: Slider(
                value: _hsvColor.saturation,
                min: 0,
                max: 1,
                onChanged: (v) => _updateColor(_hsvColor.withSaturation(v)),
              ),
            ),
          ],
        ),
              Row(
                children: [
                  Text(l10n.lightness),
                  Expanded(
                    child: Slider(
                      value: _hsvColor.value,
                      min: 0,
                      max: 1,
                      onChanged: (v) => _updateColor(_hsvColor.withValue(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
 
        // Presets
        Text(
          l10n.presets,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_namingMode)
              _InlineNamingRow(
                color: widget.currentColor,
                controller: _nameController,
                formKey: _formKey,
                onCancel: () => setState(() {
                  _namingMode = false;
                  _nameController.clear();
                }),
                onConfirm: () {
                  if (_formKey.currentState!.validate()) {
                    appState.addUserColorPreset(_nameController.text.trim(), widget.currentColor);
                    setState(() {
                      _namingMode = false;
                      _nameController.clear();
                    });
                  }
                },
              ),
            if (!_namingMode) ...[
              ...presets.map((entry) {
                final color = entry.$1;
                final isSelected = widget.currentColor.toARGB32() == color.toARGB32();
                return FilterChip(
                  selected: isSelected,
                  label: Text(entry.$2),
                  checkmarkColor: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  backgroundColor: color.withValues(alpha: 0.2),
                  selectedColor: color,
                  onSelected: (_) => widget.onColorChanged(color),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black)
                        : theme.colorScheme.onSurface,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.colorScheme.outline,
                  ),
                );
              }),
              ...userPresets.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final color = Color(p.colorValue);
                final isSelected = widget.currentColor.toARGB32() == color.toARGB32();
                return FilterChip(
                  selected: isSelected,
                  label: Text(p.name),
                  onSelected: (_) => widget.onColorChanged(color),
                  onDeleted: () => appState.removeUserColorPreset(idx),
                  deleteIconColor: isSelected
                      ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white70 : Colors.black54)
                      : theme.colorScheme.onSurfaceVariant,
                  checkmarkColor: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  backgroundColor: color.withValues(alpha: 0.2),
                  selectedColor: color,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black)
                        : theme.colorScheme.onSurface,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.colorScheme.outline,
                  ),
                );
              }),
              if (userPresets.length < 22)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.createPreset),
                  onPressed: () => setState(() => _namingMode = true),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    l10n.presetLimitReached,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        if (!_namingMode)
          FilledButton(
            onPressed: widget.onSave,
            child: Text(l10n.save),
          ),
      ],
    );
  }
}

class _InlineNamingRow extends StatelessWidget {
  final Color color;
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _InlineNamingRow({
    required this.color,
    required this.controller,
    required this.formKey,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.presetName,
                  isDense: true,
                  border: InputBorder.none,
                  counterText: "", // Hide counter
                  contentPadding: EdgeInsets.zero,
                ),
                maxLength: 16,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return ""; // Subtle error
                  if (!RegExp(r'^[a-zA-Z]+$').hasMatch(v)) return ""; 
                  return null;
                },
                onFieldSubmitted: (_) => onConfirm(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 20),
            onPressed: onConfirm,
            visualDensity: VisualDensity.compact,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _PreviewSwitch extends StatefulWidget {
  final Color activeColor;
  const _PreviewSwitch({required this.activeColor});

  @override
  State<_PreviewSwitch> createState() => _PreviewSwitchState();
}

class _PreviewSwitchState extends State<_PreviewSwitch> {
  bool _value = true;
  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      activeTrackColor: widget.activeColor.withValues(alpha: 0.5),
      activeThumbColor: widget.activeColor,
    );
  }
}

