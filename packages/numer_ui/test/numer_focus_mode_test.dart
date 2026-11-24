import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _fold = Duration(milliseconds: 240);

Widget _form(NumerSheetFocusMode focus) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      NumerFocusFold(
        hidden: focus.hides('name'),
        child: TextField(
          focusNode: focus.nodeFor('name'),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => focus.moveTo('code'),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
      NumerFocusGap(hidden: focus.hidesChrome),
      NumerFocusFold(
        hidden: focus.hides('code'),
        child: TextField(
          focusNode: focus.nodeFor('code'),
          decoration: const InputDecoration(labelText: 'Code'),
        ),
      ),
      NumerFocusFold(
        hidden: focus.hidesChrome,
        child: const Text('helper text'),
      ),
    ],
  );
}

Future<NumerSheetFocusMode> _open(
  WidgetTester tester, {
  String? doneLabel = 'Done',
  bool reduceMotion = false,
}) async {
  final focus = NumerSheetFocusMode();
  addTearDown(focus.dispose);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNumerSheet<void>(
              context,
              title: 'Add course',
              focusMode: focus,
              doneLabel: doneLabel,
              builder: (_) => _form(focus),
              primaryAction: FilledButton(
                onPressed: () {},
                child: const Text('Save'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return focus;
}

void _keyboard(WidgetTester tester, {required bool up}) {
  tester.view.viewInsets = FakeViewPadding(bottom: up ? 600 : 0);
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _typeIn(WidgetTester tester, String label) async {
  await tester.tap(_field(label));
  await tester.pump();
  _keyboard(tester, up: true);
  await tester.pumpAndSettle();
}

void _expectWholeForm() {
  expect(find.text('Add course'), findsOneWidget);
  expect(_field('Name'), findsOneWidget);
  expect(_field('Code'), findsOneWidget);
  expect(find.text('helper text'), findsOneWidget);
  expect(find.text('Save'), findsOneWidget);
  expect(find.text('Done'), findsNothing);
}

void main() {
  testWidgets('typing folds everything but the active field', (tester) async {
    await _open(tester);
    _expectWholeForm();

    await _typeIn(tester, 'Name');

    expect(_field('Name'), findsOneWidget);
    expect(_field('Code'), findsNothing);
    expect(find.text('Add course'), findsNothing);
    expect(find.text('helper text'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      tester.getSize(find.byType(SingleChildScrollView)).width - 32,
    );
  });

  testWidgets('focus without a keyboard folds nothing', (tester) async {
    await _open(tester);
    await tester.tap(_field('Name'));
    await tester.pumpAndSettle();

    _expectWholeForm();
  });

  testWidgets('done drops focus and brings the form back', (tester) async {
    final focus = await _open(tester);
    await _typeIn(tester, 'Name');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(focus.nodeFor('name').hasFocus, isFalse);
    _expectWholeForm();
  });

  testWidgets('next opens the fold of the following field', (tester) async {
    final focus = await _open(tester);
    await _typeIn(tester, 'Name');

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(_field('Name'), findsNothing);
    expect(_field('Code'), findsOneWidget);
    expect(focus.nodeFor('code').hasFocus, isTrue);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a returning keyboard folds around the focused field', (
    tester,
  ) async {
    final focus = await _open(tester);
    await _typeIn(tester, 'Name');

    _keyboard(tester, up: false);
    await tester.pumpAndSettle();
    _expectWholeForm();
    expect(focus.nodeFor('name').hasFocus, isTrue);

    _keyboard(tester, up: true);
    await tester.pumpAndSettle();
    expect(_field('Code'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('without a done label the primary action stays', (tester) async {
    await _open(tester, doneLabel: null);
    await _typeIn(tester, 'Name');

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Add course'), findsNothing);
  });

  testWidgets('a fold takes 240 ms', (tester) async {
    await _open(tester);
    await tester.tap(_field('Name'));
    await tester.pump();
    _keyboard(tester, up: true);
    await tester.pump();
    final fold = tester.widget<AnimatedSize>(find.byType(AnimatedSize).first);

    expect(fold.duration, _fold);
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      _fold,
    );
  });

  testWidgets('reduced motion switches at once', (tester) async {
    await _open(tester, reduceMotion: true);
    await tester.tap(_field('Name'));
    await tester.pump();
    _keyboard(tester, up: true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(AnimatedSize), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Add course'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });
}
