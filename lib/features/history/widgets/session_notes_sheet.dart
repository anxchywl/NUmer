import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

class SessionNotesSheet extends StatefulWidget {
  const SessionNotesSheet({super.key, required this.initialNotes});

  final String initialNotes;

  @override
  State<SessionNotesSheet> createState() => _SessionNotesSheetState();
}

class _SessionNotesSheetState extends State<SessionNotesSheet> {
  final _focus = NumerSheetFocusMode();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    final chrome = _focus.hidesChrome;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumerFocusFold(hidden: chrome, child: _title(context)),
          NumerFocusGap(hidden: chrome, height: 12),
          _field(context),
          const SizedBox(height: 12),
          _actions(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.sessionNotes,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );
  }

  Widget _field(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus.nodeFor('notes'),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.sessionNotesHint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(160),
        FilteringTextInputFormatter.allow(
          RegExp(r'[\p{L}\p{N} ,.]', unicode: true),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasExisting = widget.initialNotes.trim().isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!_focus.hidesChrome) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(hasExisting ? l10n.updateNotes : l10n.sendNotes),
        ),
      ],
    );
  }
}
