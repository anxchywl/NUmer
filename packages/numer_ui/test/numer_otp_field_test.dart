import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

class _Calls {
  final changed = <String>[];
  final completed = <String>[];
}

Widget _app(
  _Calls calls, {
  TextEditingController? controller,
  FocusNode? focusNode,
  bool enabled = true,
  bool hasError = false,
  double width = 400,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: NumerOtpField(
            semanticsLabel: 'Code',
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            hasError: hasError,
            onChanged: calls.changed.add,
            onCompleted: calls.completed.add,
          ),
        ),
      ),
    ),
  );
}

List<String> _boxDigits(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(NumerOtpField),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .where((data) => data.length == 1)
      .toList();
}

Finder get _boxes => find.descendant(
  of: find.byType(NumerOtpField),
  matching: find.byType(Container),
);

List<BoxDecoration> _decorations(WidgetTester tester) {
  return tester
      .widgetList<Container>(_boxes)
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .toList();
}

void _mockClipboard(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    if (call.method == 'Clipboard.hasStrings') return {'value': true};
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

Future<void> _pressPasteShortcut(WidgetTester tester) async {
  final modifier = defaultTargetPlatform == TargetPlatform.iOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Future<void> _pasteFromMenu(WidgetTester tester) async {
  await tester.longPressAt(tester.getCenter(_boxes.at(3)));
  await tester.pumpAndSettle();

  expect(find.text('Paste'), findsOneWidget);
  for (final other in ['Cut', 'Copy', 'Select all', 'Select All']) {
    expect(find.text(other), findsNothing);
  }
  await tester.tap(find.text('Paste'));
  await tester.pumpAndSettle();
}

void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  final ways = {
    'the menu': _pasteFromMenu,
    'the shortcut': _pressPasteShortcut,
  };

  for (final way in ways.entries) {
    for (final typed in ['', '12', '123456']) {
      testWidgets(
        'pasting with ${way.key} over "$typed" fills every box',
        (tester) async {
          final calls = _Calls();
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          _mockClipboard(tester, 'Your code is 482 913.');
          await tester.pumpWidget(_app(calls, controller: controller));
          await tester.showKeyboard(find.byType(TextField));
          await tester.enterText(find.byType(TextField), typed);
          await tester.pumpAndSettle();
          calls.completed.clear();

          await way.value(tester);

          expect(controller.text, '482913');
          expect(_boxDigits(tester), ['4', '8', '2', '9', '1', '3']);
          expect(calls.completed, ['482913']);
        },
        variant: platforms,
      );
    }
  }

  testWidgets('a short paste is added after the typed digits', (tester) async {
    final calls = _Calls();
    _mockClipboard(tester, '345');
    await tester.pumpWidget(_app(calls));
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '12');

    await _pressPasteShortcut(tester);

    expect(_boxDigits(tester), ['1', '2', '3', '4', '5']);
    expect(calls.completed, isEmpty);
  });

  testWidgets('a code inserted by the keyboard replaces typed digits', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));
    await tester.enterText(find.byType(TextField), '12');

    await tester.enterText(find.byType(TextField), '12482913');

    expect(calls.completed, ['482913']);
  });

  testWidgets('a delete that selects first is not answered', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    tester.testTextInput.log.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '1234',
        selection: TextSelection(baseOffset: 3, extentOffset: 4),
      ),
    );
    await tester.pump();

    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.setEditingState')),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '123',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(_boxDigits(tester), ['1', '2', '3']);
    expect(calls.changed.last, '123');
  });

  testWidgets('typing over a selection still appends', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(_Calls(), controller: controller));
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '12');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 2);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '5',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    expect(controller.text, '125');
    expect(controller.selection, const TextSelection.collapsed(offset: 3));
  });

  testWidgets('typing six digits completes once', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));

    for (var length = 1; length <= 6; length++) {
      await tester.enterText(
        find.byType(TextField),
        '123456'.substring(0, length),
      );
    }
    await tester.pump();

    expect(calls.completed, ['123456']);
    expect(calls.changed, ['1', '12', '123', '1234', '12345', '123456']);
    expect(_boxDigits(tester), ['1', '2', '3', '4', '5', '6']);
  });

  testWidgets('completes again after the value drops below six', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));

    await tester.enterText(find.byType(TextField), '123456');
    await tester.enterText(find.byType(TextField), '12345');
    await tester.enterText(find.byType(TextField), '123457');

    expect(calls.completed, ['123456', '123457']);
  });

  testWidgets('a letter is ignored', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));

    await tester.enterText(find.byType(TextField), '1');
    await tester.enterText(find.byType(TextField), '1a');

    expect(calls.changed, ['1']);
    expect(_boxDigits(tester), ['1']);
  });

  testWidgets('a pasted code with separators fills the boxes', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls));

    await tester.enterText(find.byType(TextField), '123 456');
    await tester.pump();

    expect(calls.completed, ['123456']);
    expect(_boxDigits(tester), ['1', '2', '3', '4', '5', '6']);
  });

  testWidgets('a programmatic value behaves like typing', (tester) async {
    final calls = _Calls();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(calls, controller: controller));

    controller.text = '123456';
    await tester.pump();

    expect(_boxDigits(tester), ['1', '2', '3', '4', '5', '6']);
    expect(calls.changed, ['123456']);
    expect(calls.completed, ['123456']);
  });

  testWidgets('a long programmatic value is cut to six digits', (tester) async {
    final calls = _Calls();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(calls, controller: controller));

    controller.text = '12345678';
    await tester.pump();

    expect(controller.text, '123456');
    expect(calls.completed, ['123456']);
  });

  testWidgets('a value present at first build is picked up', (tester) async {
    final calls = _Calls();
    final controller = TextEditingController(text: '12-34-56');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(calls, controller: controller));
    await tester.pump();

    expect(controller.text, '123456');
    expect(calls.completed, ['123456']);
  });

  testWidgets('the next digit goes to the end', (tester) async {
    final calls = _Calls();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(calls, controller: controller));

    controller.text = '12';
    controller.selection = const TextSelection.collapsed(offset: 0);

    expect(controller.selection, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('an error clears the field and focuses it', (tester) async {
    final calls = _Calls();
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    Widget app({bool enabled = true, bool hasError = false}) => _app(
      calls,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      hasError: hasError,
    );
    await tester.pumpWidget(app());
    controller.text = '123456';
    await tester.pumpWidget(app(enabled: false));

    await tester.pumpWidget(app(hasError: true));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(_boxDigits(tester), isEmpty);
    expect(focusNode.hasFocus, isTrue);
    expect(calls.changed.last, isEmpty);
    final error = Theme.of(
      tester.element(find.byType(NumerOtpField)),
    ).colorScheme.error;
    for (final decoration in _decorations(tester)) {
      expect(decoration.border, Border.all(color: error, width: 2));
    }
  });

  testWidgets('tapping any box focuses the field', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(_app(_Calls(), focusNode: focusNode));

    for (var index = 0; index < 6; index++) {
      focusNode.unfocus();
      // quick successive taps count as a double tap
      await tester.pump(kDoubleTapTimeout);

      await tester.tapAt(tester.getCenter(_boxes.at(index)));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue, reason: 'box $index');
      expect(tester.testTextInput.isVisible, isTrue, reason: 'box $index');
    }
  });

  testWidgets('only the focused box has a primary border', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(_app(_Calls(), focusNode: focusNode));
    expect(_decorations(tester).where((box) => box.border != null), isEmpty);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    final primary = Theme.of(
      tester.element(find.byType(NumerOtpField)),
    ).colorScheme.primary;
    final borders = _decorations(tester).map((box) => box.border).toList();
    expect(borders[2], Border.all(color: primary, width: 2));
    expect(borders.nonNulls, hasLength(1));
  });

  testWidgets('is one semantics node with label and value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_Calls()));
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();

    expect(find.bySemanticsLabel('Code'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Code'));
    expect(node.label, 'Code');
    expect(node.value, '123');
    expect(node.childrenCount, 0);
    handle.dispose();
  });

  testWidgets('asks for a one time code on a numeric keyboard', (tester) async {
    await tester.pumpWidget(_app(_Calls()));

    final field = tester.widget<EditableText>(find.byType(EditableText));

    expect(field.autofillHints, [AutofillHints.oneTimeCode]);
    expect(field.keyboardType, TextInputType.number);
  });

  testWidgets('fits a 320 pt screen', (tester) async {
    await tester.pumpWidget(_app(_Calls(), width: 320));

    expect(tester.takeException(), isNull);
    final field = tester.getRect(find.byType(NumerOtpField));
    for (var index = 0; index < 6; index++) {
      final box = tester.getRect(_boxes.at(index));
      expect(box.width, lessThanOrEqualTo(48));
      expect(box.height, 56);
      expect(box.left, greaterThanOrEqualTo(field.left));
      expect(box.right, lessThanOrEqualTo(field.right));
    }
  });
}
