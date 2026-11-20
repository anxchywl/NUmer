import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class TimeInputsRow extends StatelessWidget {
  const TimeInputsRow({
    super.key,
    required this.hCtrl,
    required this.mCtrl,
    required this.sCtrl,
    required this.hNode,
    required this.mNode,
    required this.sNode,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController hCtrl;
  final TextEditingController mCtrl;
  final TextEditingController sCtrl;
  final FocusNode hNode;
  final FocusNode mNode;
  final FocusNode sNode;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _numField(
          context,
          hCtrl,
          hNode,
          AppLocalizations.of(context)!.hUnit,
          maxLen: 2,
          nextNode: mNode,
          nextCtrl: mCtrl,
        ),
        const SizedBox(width: 12),
        _numField(
          context,
          mCtrl,
          mNode,
          AppLocalizations.of(context)!.mUnit,
          maxLen: 2,
          prevNode: hNode,
          prevCtrl: hCtrl,
          nextNode: sNode,
          nextCtrl: sCtrl,
        ),
        const SizedBox(width: 12),
        _numField(
          context,
          sCtrl,
          sNode,
          AppLocalizations.of(context)!.sUnit,
          maxLen: 2,
          prevNode: mNode,
          prevCtrl: mCtrl,
        ),
      ],
    );
  }

  void _focusNumericField(
    BuildContext context,
    FocusNode node,
    TextEditingController ctrl,
  ) {
    if (!context.mounted) return;
    final scope = FocusScope.of(context);
    final current = scope.focusedChild;
    if (current != null && current != node) {
      current.unfocus(disposition: UnfocusDisposition.scope);
    }
    scope.requestFocus(node);
    final offset = ctrl.text.length;
    // Keep cursor in the tapped field and at the end of current value.
    Future.microtask(() {
      if (!context.mounted) return;
      if (!node.hasFocus) {
        FocusScope.of(context).requestFocus(node);
      }
      ctrl.selection = TextSelection.collapsed(offset: offset);
    });
  }

  Widget _numField(
    BuildContext context,
    TextEditingController ctrl,
    FocusNode node,
    String label, {
    required int maxLen,
    FocusNode? prevNode,
    TextEditingController? prevCtrl,
    FocusNode? nextNode,
    TextEditingController? nextCtrl,
  }) {
    return SizedBox(
      width: 84,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _focusNumericField(context, node, ctrl) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _textField(
              context,
              ctrl,
              node,
              label,
              maxLen: maxLen,
              prevNode: prevNode,
              prevCtrl: prevCtrl,
              nextNode: nextNode,
              nextCtrl: nextCtrl,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    BuildContext context,
    TextEditingController ctrl,
    FocusNode node,
    String label, {
    required int maxLen,
    FocusNode? prevNode,
    TextEditingController? prevCtrl,
    FocusNode? nextNode,
    TextEditingController? nextCtrl,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        key: ValueKey(label),
        controller: ctrl,
        focusNode: node,
        enabled: enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onTap: enabled ? () => _focusNumericField(context, node, ctrl) : null,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLen),
        ],
        onChanged: (value) {
          onChanged();
          if (!enabled || !node.hasFocus) return;
          if (value.isEmpty &&
              prevNode != null &&
              prevCtrl != null &&
              prevCtrl.text.isNotEmpty) {
            _focusNumericField(context, prevNode, prevCtrl);
            return;
          }
          if (value.length < maxLen) return;
          if (nextNode != null && nextCtrl != null) {
            _focusNumericField(context, nextNode, nextCtrl);
          }
        },
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
