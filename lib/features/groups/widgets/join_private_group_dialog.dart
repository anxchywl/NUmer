import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

class JoinPrivateGroupDialog extends StatefulWidget {
  const JoinPrivateGroupDialog({
    super.key,
    required this.groupName,
    required this.onJoin,
  });

  final String groupName;
  final ValueChanged<String> onJoin;

  @override
  State<JoinPrivateGroupDialog> createState() => _JoinPrivateGroupDialogState();
}

class _JoinPrivateGroupDialogState extends State<JoinPrivateGroupDialog> {
  final _controller = TextEditingController();
  final _focus = NumerSheetFocusMode();
  bool _isValid = false;

  void _validate() {
    final text = _controller.text;
    final valid = text.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _dialog);

  Widget _dialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chrome = _focus.hidesChrome;
    return AlertDialog(
      title: NumerFocusFold(
        hidden: chrome,
        child: Text(l10n.joinGroupDialogTitle(widget.groupName)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumerFocusFold(
            hidden: chrome,
            child: Text(l10n.joinGroupDialogMessage),
          ),
          NumerFocusGap(hidden: chrome),
          _codeField(l10n),
        ],
      ),
      actions: [
        if (!chrome)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        FilledButton(
          onPressed: _isValid ? _join : null,
          child: Text(l10n.joinGroup),
        ),
      ],
    );
  }

  Widget _codeField(AppLocalizations l10n) {
    return TextField(
      controller: _controller,
      focusNode: _focus.nodeFor('code'),
      decoration: InputDecoration(
        labelText: l10n.groupCodeLabel,
        border: const OutlineInputBorder(),
        hintText: l10n.joinCodeHint,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      ],
      onChanged: (_) => _validate(),
    );
  }

  void _join() {
    Navigator.of(context).pop();
    widget.onJoin(_controller.text);
  }
}
