import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class ProfileFields extends StatelessWidget {
  const ProfileFields({
    super.key,
    required this.name,
    required this.major,
    required this.contact,
    required this.goal,
    required this.autofocusName,
    this.focus,
  });

  final TextEditingController name;
  final TextEditingController major;
  final TextEditingController contact;
  final TextEditingController goal;
  final bool autofocusName;
  final NumerSheetFocusMode? focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _folded('name', _nameField(context)),
        _gap(),
        _folded('major', _majorField(context)),
        _gap(),
        _folded('contact', _contactField(context)),
        _gap(),
        _folded('goal', _goalField(context)),
      ],
    );
  }

  Widget _folded(String id, Widget field) {
    final focus = this.focus;
    if (focus == null) return field;
    return NumerFocusFold(hidden: focus.hides(id), child: field);
  }

  Widget _gap() =>
      NumerFocusGap(hidden: focus?.hidesChrome ?? false, height: 10);

  // only a dialog with a focus mode moves between fields from the keyboard
  TextInputAction? _action(String? next) {
    if (focus == null) return null;
    return next == null ? TextInputAction.done : TextInputAction.next;
  }

  ValueChanged<String>? _moveTo(String id) {
    final focus = this.focus;
    return focus == null ? null : (_) => focus.moveTo(id);
  }

  Widget _nameField(BuildContext context) {
    return TextFormField(
      controller: name,
      focusNode: focus?.nodeFor('name'),
      textInputAction: _action('major'),
      onFieldSubmitted: _moveTo('major'),
      autofocus: autofocusName,
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
      validator: (value) => _validateName(context, value),
    );
  }

  String? _validateName(BuildContext context, String? value) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return l10n.nameRequired;
    if (trimmed.length < 2) return l10n.displayNameLength;
    if (!RegExp(r'^[\p{L}\p{N} ]+$', unicode: true).hasMatch(trimmed)) {
      return l10n.displayNameInvalidChars;
    }
    return null;
  }

  Widget _majorField(BuildContext context) {
    return TextFormField(
      controller: major,
      focusNode: focus?.nodeFor('major'),
      textInputAction: _action('contact'),
      onFieldSubmitted: _moveTo('contact'),
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
    );
  }

  Widget _contactField(BuildContext context) {
    return TextFormField(
      controller: contact,
      focusNode: focus?.nodeFor('contact'),
      textInputAction: _action('goal'),
      onFieldSubmitted: _moveTo('goal'),
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
    );
  }

  Widget _goalField(BuildContext context) {
    return TextFormField(
      controller: goal,
      focusNode: focus?.nodeFor('goal'),
      textInputAction: _action(null),
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
    );
  }
}
