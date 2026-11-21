import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

class _CustomCancel extends DefaultMaterialLocalizations {
  const _CustomCancel();

  @override
  String get cancelButtonLabel => 'Keep it';
}

class _CustomCancelDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _CustomCancelDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _CustomCancel());

  @override
  bool shouldReload(_CustomCancelDelegate old) => false;
}

Widget _app(Future<void> Function(BuildContext) open) {
  return MaterialApp(
    localizationsDelegates: const [_CustomCancelDelegate()],
    home: Scaffold(
      body: SizedBox(
        height: 200,
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<List<bool>> _openConfirm(
  WidgetTester tester, {
  bool destructive = false,
}) async {
  final results = <bool>[];
  await tester.pumpWidget(
    _app((context) async {
      results.add(
        await showNumerConfirm(
          context,
          title: 'Delete the course?',
          body: 'Its sessions stay.',
          confirmLabel: 'Delete',
          destructive: destructive,
        ),
      );
    }),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('opens above a nested navigator with its parts', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showNumerSheet<void>(
          context,
          title: 'Add course',
          builder: (_) => const Text('content'),
          primaryAction: FilledButton(
            onPressed: () {},
            child: const Text('Add'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final shape = sheet.shape! as RoundedRectangleBorder;
    final root = tester.state<NavigatorState>(find.byType(Navigator).first);

    expect(Navigator.of(tester.element(find.byType(BottomSheet))), same(root));
    expect(sheet.showDragHandle, isTrue);
    expect(
      shape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(20)),
    );
    expect(find.text('Add course'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)).bottom, 600);
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      tester.getSize(find.byType(SingleChildScrollView)).width - 32,
    );
  });

  testWidgets('confirm returns true', (tester) async {
    final results = await _openConfirm(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('cancel takes its word from material and returns false', (
    tester,
  ) async {
    final results = await _openConfirm(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Keep it'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('a tap on the scrim returns false', (tester) async {
    final results = await _openConfirm(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('a destructive confirm fills with error', (tester) async {
    await _openConfirm(tester, destructive: true);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final scheme = Theme.of(
      tester.element(find.byType(FilledButton)),
    ).colorScheme;

    expect(button.style!.backgroundColor!.resolve({}), scheme.error);
    expect(button.style!.foregroundColor!.resolve({}), scheme.onError);
  });
}
