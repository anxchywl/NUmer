import 'package:flutter/widgets.dart';

// which field of a sheet holds the keyboard. a sheet on a phone gives up most
// of its height to the keyboard, and what is left is usually the wrong half, so
// while a field is being typed into everything else folds away
class NumerSheetFocusMode extends ChangeNotifier {
  final Map<Object, FocusNode> _nodes = {};
  Object? _typingIn;
  bool _keyboardVisible = false;

  // keyed on the keyboard being on screen, not on focus alone: a field can hold
  // focus with no keyboard showing, as on a simulator with a hardware keyboard,
  // and then there is no height to recover
  bool get isTyping => _typingIn != null && _keyboardVisible;

  bool hides(Object id) => isTyping && _typingIn != id;

  bool get hidesChrome => isTyping;

  // the view insets are the only honest signal that the keyboard is up
  void setKeyboardVisible(bool value) {
    if (value == _keyboardVisible) return;
    _keyboardVisible = value;
    // a field can keep focus while the keyboard is away, and no focus event
    // announces its return
    _typingIn = value ? _typingIn ?? _focusedId() : null;
  }

  Object? _focusedId() {
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return null;
  }

  // the same node every time, so a rebuilt field does not drop focus
  FocusNode nodeFor(Object id) => _nodes.putIfAbsent(id, () {
    final node = FocusNode(debugLabel: 'NumerSheetFocusMode($id)');
    node.addListener(() => _focusChanged(id, node));
    return node;
  });

  void _focusChanged(Object id, FocusNode node) {
    final Object? next;
    if (node.hasFocus) {
      next = id;
    } else if (_typingIn == id && !_keyboardVisible) {
      // a tap straight from one field to another can land the loss before the
      // gain; while the keyboard stays up, focus mode holds rather than blinking
      next = null;
    } else {
      next = _typingIn;
    }
    if (next == _typingIn) return;
    _typingIn = next;
    notifyListeners();
  }

  // a folded field is out of the tree, so the next-field key opens its fold
  // first and asks for focus once it is back
  void moveTo(Object id) {
    if (_typingIn == id) return;
    _typingIn = id;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => nodeFor(id).requestFocus(),
    );
  }

  // what Done does: the keyboard goes, and the whole form comes back with it
  // at once rather than waiting for the keyboard to finish leaving
  void release() {
    for (final node in _nodes.values) {
      if (node.hasFocus) node.unfocus();
    }
    if (_typingIn == null) return;
    _typingIn = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
    super.dispose();
  }
}
