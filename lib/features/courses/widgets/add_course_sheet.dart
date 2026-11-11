import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/color_picker_button.dart';

import '../course.dart';
import '../course_format.dart';

Future<void> showAddCourseSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const AddCourseSheet(),
  );
}

class AddCourseSheet extends StatefulWidget {
  const AddCourseSheet({super.key});

  @override
  State<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<AddCourseSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Color _picked = courseColorChoices.first;

  final _credits = TextEditingController();
  int _expLevel = 3;

  bool _showCustomPicker = false;

  bool get _hasCredits {
    final v = double.tryParse(_credits.text.trim());
    return v != null && v > 0;
  }

  @override
  void initState() {
    super.initState();
    _credits.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      left: 16,
      right: 16,
      top: 16,
    );

    return Padding(
      padding: pad,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.addCourse,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _nameField(),
              const SizedBox(height: 12),
              ..._colorSection(),
              const SizedBox(height: 16),
              _creditsField(),
              _experienceSection(),
              _saveButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _name,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.courseName,
        hintText: AppLocalizations.of(context)!.courseNameHint,
      ),
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        LengthLimitingTextInputFormatter(32),
        FilteringTextInputFormatter.allow(
          RegExp(r'[\p{L}\p{N} ]', unicode: true),
        ),
      ],
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppLocalizations.of(context)!.required
          : null,
    );
  }

  List<Widget> _colorSection() {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context)!.color,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      const SizedBox(height: 8),
      _swatches(),
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        crossFadeState: _showCustomPicker
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: const SizedBox.shrink(),
        secondChild: Column(
          children: [
            const SizedBox(height: 16),
            CustomColorPicker(
              initial: _picked,
              onChanged: (c) => setState(() => _picked = c),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _swatches() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in courseColorChoices.take(13))
          GestureDetector(
            onTap: () => setState(() {
              _picked = c;
              _showCustomPicker = false;
            }),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: _picked.toARGB32() == c.toARGB32()
                    ? Border.all(width: 3, color: Colors.black54)
                    : null,
              ),
            ),
          ),
        ColorPickerButton(
          color: _picked,
          onCustomTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _showCustomPicker = !_showCustomPicker);
          },
          onColorPicked: (color) => setState(() => _picked = color),
        ),
      ],
    );
  }

  Widget _creditsField() {
    return TextFormField(
      controller: _credits,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        final val = double.tryParse(v);
        if (val == null) return 'Invalid number';
        if (val > 64) return 'Max 64';
        return null;
      },
      inputFormatters: [
        LengthLimitingTextInputFormatter(2),
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
      ],
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.creditsOptional,
        hintText: AppLocalizations.of(context)!.creditsHint,
        helperText: AppLocalizations.of(context)!.creditsHelper,
      ),
    );
  }

  Widget _experienceSection() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState: _hasCredits
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.experienceLevel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_expLevel',
            value: _expLevel.toDouble(),
            onChanged: (v) => setState(() => _expLevel = v.round()),
          ),
          Text(
            '${expShortLabel(context, _expLevel)} ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return FilledButton(
      onPressed: _save,
      child: Text(AppLocalizations.of(context)!.save),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final creditsVal = double.tryParse(_credits.text.trim());
    final course = Course(
      id: id,
      name: _name.text.trim(),
      day: 'Mon',
      start: '09:00',
      end: '10:00',
      colorValue: _picked.toARGB32(),
      credits: creditsVal,
      expLevel: _hasCredits ? _expLevel : null,
    );

    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);

    await appState.addCourse(course);

    if (!mounted) return;
    navigator.pop();
  }
}
