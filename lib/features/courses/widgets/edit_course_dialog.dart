import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/color_picker_button.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

import '../course.dart';
import '../course_format.dart';

Future<void> showEditCourseDialog(BuildContext context, Course course) {
  final state = context.read<AppState>();

  final live = state.courses.firstWhere(
    (c) => c.id == course.id,
    orElse: () => course,
  );

  return showDialog<void>(
    context: context,
    builder: (_) => _EditCourseDialog(course: live, host: context),
  );
}

class _EditCourseDialog extends StatefulWidget {
  const _EditCourseDialog({required this.course, required this.host});

  final Course course;
  final BuildContext host;

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  final _focus = NumerSheetFocusMode();
  late final _name = TextEditingController(text: widget.course.name);
  late Color _selected = widget.course.color;
  bool _showCustomPicker = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _dialog);

  Widget _dialog(BuildContext context) {
    return AlertDialog(
      title: NumerFocusFold(
        hidden: _focus.hidesChrome,
        child: Text(AppLocalizations.of(widget.host)!.editCourse),
      ),
      content: _editContent(
        widget.host,
        context,
        _name,
        focus: _focus,
        selected: _selected,
        showCustomPicker: _showCustomPicker,
        onSwatch: (c) => setState(() {
          _selected = c;
          _showCustomPicker = false;
        }),
        onToggleCustom: () =>
            setState(() => _showCustomPicker = !_showCustomPicker),
        onColorPicked: (color) => setState(() => _selected = color),
      ),
      actions: [
        if (!_focus.hidesChrome)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: () => _saveCourse(
            widget.host,
            context,
            widget.course,
            _name.text,
            _selected,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Widget _editContent(
  BuildContext context,
  BuildContext ctx,
  TextEditingController nameCtrl, {
  required NumerSheetFocusMode focus,
  required Color selected,
  required bool showCustomPicker,
  required ValueChanged<Color> onSwatch,
  required VoidCallback onToggleCustom,
  required ValueChanged<Color> onColorPicked,
}) {
  final chrome = focus.hidesChrome;
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _editNameField(context, nameCtrl, focus.nodeFor('name')),
          NumerFocusGap(hidden: chrome, height: 12),
          NumerFocusFold(
            hidden: chrome,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.color,
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                _editSwatches(
                  selected: selected,
                  onSwatch: onSwatch,
                  onToggleCustom: onToggleCustom,
                  onColorPicked: onColorPicked,
                ),
                _editCustomPicker(showCustomPicker, selected, onColorPicked),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _editCustomPicker(
  bool shown,
  Color selected,
  ValueChanged<Color> onColorPicked,
) {
  return AnimatedCrossFade(
    duration: const Duration(milliseconds: 220),
    crossFadeState: shown
        ? CrossFadeState.showSecond
        : CrossFadeState.showFirst,
    firstChild: const SizedBox.shrink(),
    secondChild: Column(
      children: [
        const SizedBox(height: 16),
        CustomColorPicker(initial: selected, onChanged: onColorPicked),
      ],
    ),
  );
}

Widget _editNameField(
  BuildContext context,
  TextEditingController nameCtrl,
  FocusNode node,
) {
  return TextField(
    controller: nameCtrl,
    focusNode: node,
    autofocus: true,
    textCapitalization: TextCapitalization.words,
    inputFormatters: [
      LengthLimitingTextInputFormatter(32),
      FilteringTextInputFormatter.allow(
        RegExp(r'[\p{L}\p{N} ]', unicode: true),
      ),
    ],
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context)!.courseName,
      border: const OutlineInputBorder(),
    ),
  );
}

Widget _editSwatches({
  required Color selected,
  required ValueChanged<Color> onSwatch,
  required VoidCallback onToggleCustom,
  required ValueChanged<Color> onColorPicked,
}) {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final c in courseColorChoices.take(9))
        GestureDetector(
          onTap: () => onSwatch(c),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: selected.toARGB32() == c.toARGB32()
                  ? Border.all(width: 3, color: Colors.black54)
                  : null,
            ),
          ),
        ),
      ColorPickerButton(
        color: selected,
        onCustomTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onToggleCustom();
        },
        onColorPicked: onColorPicked,
      ),
    ],
  );
}

Future<void> _saveCourse(
  BuildContext context,
  BuildContext ctx,
  Course course,
  String name,
  Color selected,
) async {
  final newName = name.trim();
  if (newName.isEmpty) return;

  final updated = course.copyWith(
    name: newName,
    colorValue: selected.toARGB32(),
  );

  final navigator = Navigator.of(ctx);
  final appState = ctx.read<AppState>();

  await appState.updateCourse(updated);

  if (!context.mounted) {
    return;
  }
  navigator.pop();
}
