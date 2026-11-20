import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/color_picker_button.dart';

import '../course.dart';
import '../course_format.dart';

Future<void> showEditCourseDialog(BuildContext context, Course course) {
  final state = context.read<AppState>();

  final live = state.courses.firstWhere(
    (c) => c.id == course.id,
    orElse: () => course,
  );

  final nameCtrl = TextEditingController(text: live.name);
  Color selected = live.color;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      bool showCustomPicker = false;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.editCourse),
            content: _editContent(
              context,
              ctx,
              nameCtrl,
              selected: selected,
              showCustomPicker: showCustomPicker,
              onSwatch: (c) => setLocal(() {
                selected = c;
                showCustomPicker = false;
              }),
              onToggleCustom: () =>
                  setLocal(() => showCustomPicker = !showCustomPicker),
              onColorPicked: (color) => setLocal(() => selected = color),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    _saveCourse(context, ctx, live, nameCtrl.text, selected),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _editContent(
  BuildContext context,
  BuildContext ctx,
  TextEditingController nameCtrl, {
  required Color selected,
  required bool showCustomPicker,
  required ValueChanged<Color> onSwatch,
  required VoidCallback onToggleCustom,
  required ValueChanged<Color> onColorPicked,
}) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _editNameField(context, nameCtrl),
          const SizedBox(height: 12),
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
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showCustomPicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 16),
                CustomColorPicker(initial: selected, onChanged: onColorPicked),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _editNameField(BuildContext context, TextEditingController nameCtrl) {
  return TextField(
    controller: nameCtrl,
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
