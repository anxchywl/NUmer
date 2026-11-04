import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

const double _boxWidth = 48;
const double _boxHeight = 56;
const double _borderWidth = 2;

final RegExp _nonDigits = RegExp('[^0-9]');

// handles would be drawn over the boxes, which stand in for the text
final TextSelectionControls _noHandles = _NoHandles();

class _NoHandles extends EmptyTextSelectionControls
    with TextSelectionHandleControls {}

// digits only ever go to the end, and a whole code replaces what was typed
class _AppendingFormatter extends TextInputFormatter {
  const _AppendingFormatter(this.length);

  final int length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final added = _addedText(oldValue, newValue.text);
    if (added.isEmpty) return newValue;
    final isWholeCode = added.replaceAll(_nonDigits, '').length >= length;
    final text = isWholeCode ? added : oldValue.text + added;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _addedText(TextEditingValue oldValue, String text) {
    final selection = oldValue.selection;
    final replaces = selection.isValid && !selection.isCollapsed;
    final before = replaces
        ? selection.textBefore(oldValue.text)
        : oldValue.text;
    final after = replaces ? selection.textAfter(oldValue.text) : '';
    final fits = text.length >= before.length + after.length;
    if (!fits || !text.startsWith(before) || !text.endsWith(after)) return '';
    return text.substring(before.length, text.length - after.length);
  }
}

class NumerOtpField extends StatefulWidget {
  const NumerOtpField({
    super.key,
    required this.onCompleted,
    required this.semanticsLabel,
    this.length = 6,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
    this.controller,
    this.focusNode,
    this.autofocus = false,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool hasError;
  final String semanticsLabel;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<NumerOtpField> createState() => _NumerOtpFieldState();
}

class _NumerOtpFieldState extends State<NumerOtpField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  String _value = '';

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleText);
    _focusNode.addListener(_handleFocus);
    if (_controller.text.isNotEmpty) _afterFrame(_handleText);
  }

  @override
  void didUpdateWidget(NumerOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_handleText);
      _controller.addListener(_handleText);
      _afterFrame(_handleText);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_handleFocus);
      _focusNode.addListener(_handleFocus);
    }
    if (widget.hasError && !oldWidget.hasError) _afterFrame(_restart);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleText);
    _focusNode.removeListener(_handleFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  // callers react by rebuilding, which is illegal while this widget is being built
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _restart() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleFocus() => setState(() {});

  void _handleText() {
    final text = _controller.text;
    final digits = _firstDigits(text);
    final end = TextSelection.collapsed(offset: digits.length);
    final selection = _controller.selection;
    // ios selects a digit before deleting it, and answering that undoes the delete
    final strayCursor = selection.isCollapsed && selection != end;
    if (text != digits || strayCursor) {
      _controller.value = TextEditingValue(text: digits, selection: end);
      return;
    }
    if (digits == _value) return;

    setState(() => _value = digits);
    widget.onChanged?.call(digits);
    if (digits.length == widget.length) widget.onCompleted(digits);
  }

  String _firstDigits(String text) {
    final digits = text.replaceAll(_nonDigits, '');
    if (digits.length <= widget.length) return digits;
    return digits.substring(0, widget.length);
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: widget.semanticsLabel,
        child: Stack(
          children: [
            Positioned.fill(child: _buildHiddenField()),
            IgnorePointer(child: ExcludeSemantics(child: _buildBoxes())),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenField() {
    return TextSelectionTheme(
      data: const TextSelectionThemeData(selectionColor: Colors.transparent),
      child: _buildTextField(),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      style: context.text.sectionTitle.copyWith(color: Colors.transparent),
      cursorColor: Colors.transparent,
      showCursor: false,
      selectionControls: _noHandles,
      contextMenuBuilder: _buildPasteMenu,
      magnifierConfiguration: TextMagnifierConfiguration.disabled,
      decoration: const InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        counterText: '',
      ),
      autofillHints: const [AutofillHints.oneTimeCode],
      keyboardType: TextInputType.number,
      inputFormatters: [
        _AppendingFormatter(widget.length),
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(widget.length),
      ],
    );
  }

  Widget _buildPasteMenu(BuildContext context, EditableTextState field) {
    if (SystemContextMenu.isSupportedByField(field)) {
      return SystemContextMenu.editableText(
        editableTextState: field,
        items: const [IOSSystemContextMenuItemPaste()],
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: field.contextMenuAnchors,
      buttonItems: [
        for (final item in field.contextMenuButtonItems)
          if (item.type == ContextMenuButtonType.paste) item,
      ],
    );
  }

  Widget _buildBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: NumerSpace.sm,
      children: [
        for (var index = 0; index < widget.length; index++)
          Flexible(child: _buildBox(index)),
      ],
    );
  }

  Widget _buildBox(int index) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: _boxWidth),
      height: _boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NumerRadius.md),
        border: _borderFor(index, colors),
      ),
      child: Text(
        index < _value.length ? _value[index] : '',
        style: context.text.sectionTitle,
      ),
    );
  }

  Border? _borderFor(int index, ColorScheme colors) {
    if (widget.hasError) {
      return Border.all(color: colors.error, width: _borderWidth);
    }
    // a full field keeps the last box marked
    final active = _value.length.clamp(0, widget.length - 1);
    if (!_focusNode.hasFocus || index != active) return null;
    return Border.all(color: colors.primary, width: _borderWidth);
  }
}
