import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

import '../models/profile_avatar.dart';
import 'color_picker_button.dart';
import 'app_toast.dart';

class ProfileFormData {
  const ProfileFormData({
    required this.name,
    this.major,
    this.goal,
    this.contact,
    this.avatarIndex,
    this.avatarColorValue,
    this.avatarBytes,
  });

  final String name;
  final String? major;
  final String? goal;
  final String? contact;
  final int? avatarIndex;
  final int? avatarColorValue;
  final Uint8List? avatarBytes;
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initialName,
    this.initialMajor,
    this.initialContact,
    this.initialGoal,
    this.initialAvatarIndex,
    this.initialAvatarColorValue,
    this.initialAvatarBytes,
    required this.primaryButtonLabel,
    required this.onSubmit,
    this.autofocusName = false,
  });

  final String initialName;
  final String? initialMajor;
  final String? initialContact;
  final String? initialGoal;
  final int? initialAvatarIndex;
  final int? initialAvatarColorValue;
  final Uint8List? initialAvatarBytes;
  final String primaryButtonLabel;
  final Future<void> Function(ProfileFormData data) onSubmit;
  final bool autofocusName;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _majorCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _goalCtrl;

  int? _avatarIndex;
  int? _avatarColorValue;
  Uint8List? _customAvatarBytes;
  bool _saving = false;
  bool _saved = false;
  bool _showColorPicker = false;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _majorCtrl = TextEditingController(text: widget.initialMajor ?? '');
    _contactCtrl = TextEditingController(text: widget.initialContact ?? '');
    _goalCtrl = TextEditingController(text: widget.initialGoal ?? '');
    _avatarIndex = widget.initialAvatarIndex;
    _avatarColorValue = widget.initialAvatarColorValue;
    _customAvatarBytes = widget.initialAvatarBytes;
    _nameCtrl.addListener(_handleFieldChange);
    _majorCtrl.addListener(_handleFieldChange);
    _contactCtrl.addListener(_handleFieldChange);
    _goalCtrl.addListener(_handleFieldChange);
  }

  @override
  void didUpdateWidget(covariant ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName &&
        widget.initialName != _nameCtrl.text) {
      _nameCtrl.text = widget.initialName;
    }
    if (oldWidget.initialMajor != widget.initialMajor &&
        widget.initialMajor != _majorCtrl.text) {
      _majorCtrl.text = widget.initialMajor ?? '';
    }
    if (oldWidget.initialContact != widget.initialContact &&
        widget.initialContact != _contactCtrl.text) {
      _contactCtrl.text = widget.initialContact ?? '';
    }
    if (oldWidget.initialGoal != widget.initialGoal &&
        widget.initialGoal != _goalCtrl.text) {
      _goalCtrl.text = widget.initialGoal ?? '';
    }
    if (oldWidget.initialAvatarIndex != widget.initialAvatarIndex) {
      setState(() {
        _avatarIndex = widget.initialAvatarIndex;
      });
    }
    if (oldWidget.initialAvatarColorValue != widget.initialAvatarColorValue) {
      setState(() {
        _avatarColorValue = widget.initialAvatarColorValue;
      });
    }
    if (oldWidget.initialAvatarBytes != widget.initialAvatarBytes) {
      setState(() {
        _customAvatarBytes = widget.initialAvatarBytes;
      });
    }
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _nameCtrl
      ..removeListener(_handleFieldChange)
      ..dispose();
    _majorCtrl
      ..removeListener(_handleFieldChange)
      ..dispose();
    _contactCtrl
      ..removeListener(_handleFieldChange)
      ..dispose();
    _goalCtrl
      ..removeListener(_handleFieldChange)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChange() {
    if (mounted) setState(() {});
  }

  Future<void> _pickCustomAvatar() async {
    try {
      showAppMessage(
        context,
        AppLocalizations.of(context)!.customPhotosUnavailable,
        isError: true,
      );
    } catch (err) {
      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(context)!.unableToPickImage,
        isError: true,
      );
    }
  }

  bool get _isNameValid => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saved = false;
    });

    final data = ProfileFormData(
      name: _nameCtrl.text.trim(),
      major: _majorCtrl.text.trim().isEmpty ? null : _majorCtrl.text.trim(),
      contact: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      goal: _goalCtrl.text.trim().isEmpty ? null : _goalCtrl.text.trim(),
      avatarIndex: _avatarIndex,
      avatarColorValue: _avatarColorValue,
      avatarBytes: _customAvatarBytes,
    );

    try {
      await widget.onSubmit(data);
    } catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(
        context,
        AppLocalizations.of(context)!.couldNotSaveProfile,
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
      _showColorPicker = false;
    });
    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _saved = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option =
        (_avatarIndex != null && _avatarIndex! < profileAvatarOptions.length)
            ? profileAvatarOptions[_avatarIndex!]
            : null;
    final effectiveBgColor = (_avatarColorValue != null)
        ? Color(_avatarColorValue!)
        : (option?.background ?? theme.colorScheme.primaryContainer);
    final isDark = ThemeData.estimateBrightnessForColor(effectiveBgColor) == Brightness.dark;
    final optionIconColor = isDark ? Colors.white : Colors.black87;
    final hasCustomAvatar =
        _customAvatarBytes != null && _customAvatarBytes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (hasCustomAvatar) {
                  _pickCustomAvatar();
                  return;
                }
                setState(() {
                  if (profileAvatarOptions.isEmpty) return;
                  if (_avatarIndex == null) {
                    _avatarIndex = 0;
                  } else {
                    _avatarIndex =
                        (_avatarIndex! + 1) % profileAvatarOptions.length;
                  }
                });
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: hasCustomAvatar || option != null ? 1.0 : 0.95,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: hasCustomAvatar
                      ? Colors.transparent
                      : (_avatarColorValue != null
                          ? Color(_avatarColorValue!)
                          : (option?.background ??
                              theme.colorScheme.primaryContainer)),
                  child: hasCustomAvatar
                      ? ClipOval(
                          child: Image.memory(
                            _customAvatarBytes!,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          option?.icon ?? Icons.person_rounded,
                          size: 32,
                          color: _avatarColorValue != null
                              ? (ThemeData.estimateBrightnessForColor(
                                          Color(_avatarColorValue!)) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87)
                              : optionIconColor,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey('${_nameCtrl.text}_${_goalCtrl.text}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.trim().isEmpty
                          ? AppLocalizations.of(context)!.yourName
                          : _nameCtrl.text.trim(),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _goalCtrl.text.trim().isEmpty
                          ? AppLocalizations.of(context)!.addPersonalGoal
                          : _goalCtrl.text.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: widget.autofocusName,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.nameLabel,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(32),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N} ]', unicode: true),
                  ),
                ],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppLocalizations.of(context)!.nameRequired
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _majorCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.majorLabel,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(32),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N} ]', unicode: true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.contactLabel,
                  hintText: AppLocalizations.of(context)!.contactHint,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(32),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9_@]'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _goalCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.personalGoalLabel,
                  hintText: AppLocalizations.of(context)!.personalGoalHint,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 1,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(88),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N}\s]', unicode: true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context)!.chooseAvatar,
            style: theme.textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _CustomAvatarChip(
              bytes: _customAvatarBytes,
              selected: hasCustomAvatar,
              onTap: _pickCustomAvatar,
            ),
            for (var i = 0; i < profileAvatarOptions.length; i++)
              _AvatarChip(
                option: profileAvatarOptions[i],
                selected: !hasCustomAvatar && _avatarIndex == i,
                onTap: () => setState(() {
                  _avatarIndex = i;
                  _customAvatarBytes = null;
                  _showColorPicker = true;
                }),
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _showColorPicker && _avatarIndex != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _ColorChooser(
                    selectedColorValue: _avatarColorValue,
                    onColorChanged: (cv) => setState(() => _avatarColorValue = cv),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isNameValid && !_saving ? _submit : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _buildButtonChild(),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonChild() {
    if (_saving) {
      return const SizedBox(
        key: ValueKey('saving'),
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_saved) {
      return Row(
        key: const ValueKey('saved'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.saved),
        ],
      );
    }
    return Text(
      widget.primaryButtonLabel,
      key: const ValueKey('label'),
    );
  }
}

class _CustomAvatarChip extends StatelessWidget {
  const _CustomAvatarChip({
    required this.bytes,
    required this.selected,
    required this.onTap,
  });

  final Uint8List? bytes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final bg = theme.colorScheme.surfaceContainerHighest
      .withAlpha(((selected ? 1 : 0.5) * 255).round());

    return Tooltip(
      message: AppLocalizations.of(context)!.photoLibraryUnavailable,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: selected ? 1.05 : 1.0,
        child: Opacity(
          opacity: 0.6,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bytes != null ? Colors.transparent : bg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: selected ? 3 : 1),
            ),
            child: bytes == null
                ? Icon(Icons.photo_library_rounded,
                    color: theme.colorScheme.onSurfaceVariant)
                : ClipOval(
                    child: Image.memory(
                      bytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ProfileAvatarOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? option.background
        : Theme.of(context).colorScheme.outlineVariant;
    final iconColor = profileAvatarForeground(option);
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: selected ? 1.05 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
            decoration: BoxDecoration(
            color: option.background.withAlpha(((selected ? 1 : 0.7) * 255).round()),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: selected ? 3 : 1),
          ),
          child: Icon(option.icon, color: iconColor),
        ),
      ),
    );
  }
}

class _ColorChooser extends StatefulWidget {
  final int? selectedColorValue;
  final ValueChanged<int?> onColorChanged;

  const _ColorChooser({
    required this.selectedColorValue,
    required this.onColorChanged,
  });

  @override
  State<_ColorChooser> createState() => _ColorChooserState();
}

class _ColorChooserState extends State<_ColorChooser> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.iconColor,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        CustomColorPicker(
          initial: widget.selectedColorValue != null
              ? Color(widget.selectedColorValue!)
              : Colors.grey,
          onChanged: (c) => widget.onColorChanged(c.toARGB32()),
        ),
      ],
    );
  }
}
