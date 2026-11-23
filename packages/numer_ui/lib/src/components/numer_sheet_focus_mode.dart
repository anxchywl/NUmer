import 'package:flutter/widgets.dart';

// the keyboard leaves a phone sheet too little height, so all but the active field folds away
class NumerSheetFocusMode extends ChangeNotifier {
  final Map<Object, FocusNode> _nodes = {};
  Object? _typingIn;
  bool _keyboardVisible = false;

  // focus alone is not enough, a hardware keyboard takes no height
  bool get isTyping => _typingIn != null && _keyboardVisible;

  bool hides(Object id) => isTyping && _typingIn != id;

  bool get hidesChrome => isTyping;

  // does not notify: the caller reads the view insets during build and rebuilds anyway
  void setKeyboardVisible(bool value) {
    if (value == _keyboardVisible) return;
    _keyboardVisible = value;
    // no focus event fires when the keyboard returns to a field that kept focus
    _typingIn = value ? _typingIn ?? _focusedId() : null;
  }

  Object? _focusedId() {
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return null;
  }

  // one node per id, so a rebuilt field does not drop focus
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
      // with the keyboard up a loss may precede the next gain, so hold instead of blinking
      next = null;
    } else {
      next = _typingIn;
    }
    if (next == _typingIn) return;
    _typingIn = next;
    notifyListeners();
  }

  // a folded field is out of the tree, so its fold opens before it can take focus
  void moveTo(Object id) {
    if (_typingIn == id) return;
    _typingIn = id;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => nodeFor(id).requestFocus(),
    );
  }

  // the form returns at once rather than after the keyboard finishes leaving
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
