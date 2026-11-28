import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/account/models/profile_avatar.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import 'profile_avatar_picker.dart';
import 'profile_fields.dart';

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
    this.focusMode,
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

  // set when the form sits in a dialog, null on a full screen
  final NumerSheetFocusMode? focusMode;

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
      final viewportWidth =
          MediaQuery.of(context).size.width -
          72; // Padding: 16(screen) + 20(card) * 2
      final itemWidth = 68.0;
      final offset =
          ((_avatarIndex ?? 0) * itemWidth) -
          (viewportWidth / 2) +
          (itemWidth / 2);
      _scrollController = ScrollController(
        initialScrollOffset: offset < 0 ? 0 : offset,
      );
    }
  }

  void _scrollToIndex(int index) {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final viewportWidth = _scrollController!.position.viewportDimension;
    final itemWidth = 68.0;
    final offset = (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
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
      contact: _contactCtrl.text.trim().isEmpty
          ? null
          : _contactCtrl.text.trim(),
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
    final option =
        (_avatarIndex != null && _avatarIndex! < profileAvatarOptions.length)
        ? profileAvatarOptions[_avatarIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _folded(_buildPreview(context, option)),
        Form(
          key: _formKey,
          child: ProfileFields(
            name: _nameCtrl,
            major: _majorCtrl,
            contact: _contactCtrl,
            goal: _goalCtrl,
            focus: widget.focusMode,
            autofocusName: widget.autofocusName,
          ),
        ),
        _folded(_buildAvatarSection(context, option)),
        const SizedBox(height: 24),
        _buildActions(),
      ],
    );
  }

  Widget _folded(Widget child) {
    final focus = widget.focusMode;
    if (focus == null) return child;
    return NumerFocusFold(hidden: focus.hidesChrome, child: child);
  }

  Widget _buildActions() {
    final button = FilledButton(
      onPressed: _isNameValid && !_saving ? _submit : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _buildButtonChild(),
      ),
    );
    final focus = widget.focusMode;
    if (focus == null) return button;
    return SheetDoneActions(focus: focus, actions: button);
  }

  Widget _buildPreview(BuildContext context, ProfileAvatarOption? option) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _buildPreviewAvatar(context, option),
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
    );
  }

  Color _iconColorFor(ProfileAvatarOption option) {
    final custom = _avatarColorValue;
    final background = custom != null ? Color(custom) : option.background;
    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    return isDark ? Colors.white : Colors.black87;
  }

  Color _backgroundFor(BuildContext context, ProfileAvatarOption? option) {
    final custom = _avatarColorValue;
    if (custom != null) return Color(custom);
    return option?.background ?? Theme.of(context).colorScheme.primaryContainer;
  }

  Widget _buildPreviewAvatar(
    BuildContext context,
    ProfileAvatarOption? option,
  ) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: 1.0,
      child: CircleAvatar(
        radius: 34,
        backgroundColor: option == null
            ? Colors.transparent
            : _backgroundFor(context, option),
        child: Icon(
          option?.icon ?? Icons.person,
          size: option == null ? 48 : 32,
          color: option == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : _iconColorFor(option),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(
    BuildContext context,
    ProfileAvatarOption? option,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _buildAvatarList(_backgroundFor(context, option)),
        _buildColorChooser(),
      ],
    );
  }

  Widget _buildAvatarList(Color background) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        // the list leaves the tree while typing and must come back where it was
        key: const PageStorageKey('profile_avatars'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: profileAvatarOptions.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ProfileAvatarChip(
                option: profileAvatarOptions[index],
                backgroundColor: background,
                selected: _avatarIndex == index,
                onTap: () => _selectAvatar(index),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectAvatar(int index) {
    setState(() {
      _avatarIndex = index;
      _showColorPicker = true;
    });
    _scrollToIndex(index);
  }

  Widget _buildColorChooser() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _showColorPicker && _avatarIndex != null
          ? Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ProfileColorChooser(
                selectedColorValue: _avatarColorValue,
                onColorChanged: (cv) => setState(() => _avatarColorValue = cv),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildButtonChild() {
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
    return NumerButtonChild(
      key: const ValueKey('label'),
      label: widget.primaryButtonLabel,
      loading: _saving,
      loadingHint: AppLocalizations.of(context)!.loadingHint,
    );
  }
}
