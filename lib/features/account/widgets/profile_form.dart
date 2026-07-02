import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/account/models/profile_avatar.dart';
import 'package:numer_app/shared/widgets/color_picker_button.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

class ProfileFormData {
  const ProfileFormData({
    required this.name,
    this.major,
    this.goal,
    this.contact,
    this.avatarIndex,
    this.avatarColorValue,
  });

  final String name;
  final String? major;
  final String? goal;
  final String? contact;
  final int? avatarIndex;
  final int? avatarColorValue;
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
  bool _saving = false;
  bool _saved = false;
  bool _showColorPicker = false;
  Timer? _savedTimer;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _majorCtrl = TextEditingController(text: widget.initialMajor ?? '');
    _contactCtrl = TextEditingController(text: widget.initialContact ?? '');
    _goalCtrl = TextEditingController(text: widget.initialGoal ?? '');
    _avatarIndex = widget.initialAvatarIndex;
    _avatarColorValue = widget.initialAvatarColorValue;
    


    _nameCtrl.addListener(_handleFieldChange);
    _majorCtrl.addListener(_handleFieldChange);
    _contactCtrl.addListener(_handleFieldChange);
    _goalCtrl.addListener(_handleFieldChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollController == null) {
      final viewportWidth = MediaQuery.of(context).size.width -
          72; // Padding: 16(screen) + 20(card) * 2
      final itemWidth = 68.0;
      final offset =
          ((_avatarIndex ?? 0) * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
      _scrollController =
          ScrollController(initialScrollOffset: offset < 0 ? 0 : offset);
    }
  }

  void _scrollToIndex(int index) {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final viewportWidth = _scrollController!.position.viewportDimension;
    final itemWidth = 68.0;
    final offset =
        (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
    _scrollController!.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
      if (widget.initialAvatarIndex != _avatarIndex) {
        setState(() {
          _avatarIndex = widget.initialAvatarIndex;
        });
        // Optional: Scroll to new index if updated externally
        // Optional: Scroll to new index if updated externally
        if (_avatarIndex != null) {
          _scrollToIndex(_avatarIndex!);
        }
      }
    }
    if (oldWidget.initialAvatarColorValue != widget.initialAvatarColorValue) {
      setState(() {
        _avatarColorValue = widget.initialAvatarColorValue;
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
    _scrollController?.dispose();
    super.dispose();
  }

  void _handleFieldChange() {
    if (mounted) setState(() {});
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


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: 1.0,
              child: CircleAvatar(
                radius: 34,
                backgroundColor: option == null
                    ? Colors.transparent
                    : (_avatarColorValue != null
                        ? Color(_avatarColorValue!)
                        : option.background),
                child: Icon(
                  option?.icon ?? Icons.person,
                  size: option == null ? 48 : 32,
                  color: option == null
                      ? theme.colorScheme.onSurfaceVariant
                      : (_avatarColorValue != null
                          ? (ThemeData.estimateBrightnessForColor(
                                      Color(_avatarColorValue!)) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black87)
                          : optionIconColor),
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
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N} ]', unicode: true),
                  ),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.startsWith(' ')) {
                      return oldValue;
                    }
                    return newValue;
                  }),
                ],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return AppLocalizations.of(context)!.nameRequired;
                  }
                  if (trimmed.length < 2) {
                    return AppLocalizations.of(context)!.displayNameLength;
                  }
                  if (!RegExp(r'^[\p{L}\p{N} ]+$', unicode: true).hasMatch(trimmed)) {
                    return AppLocalizations.of(context)!.displayNameInvalidChars;
                  }
                  return null;
                },
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
                    RegExp(r'[\p{L}\p{N}_@ ]', unicode: true),
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
                    RegExp(r'[\p{L}\p{N}\s,.]', unicode: true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: profileAvatarOptions.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: _AvatarChip(
                    option: profileAvatarOptions[index],
                    backgroundColor: effectiveBgColor,
                    selected: _avatarIndex == index,
                    onTap: () {
                      setState(() {
                        _avatarIndex = index;
                        _showColorPicker = true;
                        // Ensure color picker stays visible
                      });
                      _scrollToIndex(index);
                    },
                  ),
                ),
              );
            },
          ),
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



class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.option,
    required this.backgroundColor,
    required this.selected,
    required this.onTap,
  });

  final ProfileAvatarOption option;
  final Color backgroundColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final borderColor = selected
        ? backgroundColor
        : Theme.of(context).colorScheme.outlineVariant;
        
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
            color: backgroundColor.withAlpha(((selected ? 1 : 0.7) * 255).round()),
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
