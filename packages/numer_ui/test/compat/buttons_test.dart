import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/compat.dart';

import 'host.dart';

Finder _spinner() => find.bySubtype<ProgressIndicator>();

ButtonStyle _styleOf(WidgetTester tester, Type button) {
  return tester
      .widget<ButtonStyleButton>(
        find.descendant(
          of: find.byType(button),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      )
      .style!;
}

void main() {
  testWidgets('a loading primary button still says what it is doing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppPrimaryButton(
          text: 'Saving',
          isLoading: true,
          loadingHint: 'Loading',
          onPressed: () {},
        ),
      ),
    );

    expect(_spinner(), findsOneWidget);
    // a spinner alone leaves the control with no accessible name
    expect(find.text('Saving'), findsOneWidget);
  });

  testWidgets('a loading button refuses the tap it is already serving', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AppSecondaryButton(
          text: 'Reading',
          isLoading: true,
          loadingHint: 'Loading',
          onPressed: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Reading'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('a disabled button refuses the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AppTextButton(text: 'Skip', isEnabled: false, onPressed: () => taps++),
      ),
    );

    await tester.tap(find.text('Skip'), warnIfMissed: false);

    expect(taps, 0);
    expect(_spinner(), findsNothing);
  });

  for (final width in [null, double.infinity]) {
    for (final icon in [null, const AppIcon(AppIcons.send)]) {
      final shape = '${icon == null ? 'no' : 'an'} icon, width $width';
      testWidgets('loading centres the spinner and keeps the size: $shape', (
        tester,
      ) async {
        Widget button({required bool loading}) => host(
          AppPrimaryButton(
            text: 'Send',
            icon: icon,
            width: width,
            isLoading: loading,
            loadingHint: 'Loading',
            onPressed: () {},
          ),
        );

        await tester.pumpWidget(button(loading: false));
        final resting = tester.getSize(find.byType(AppPrimaryButton));
        await tester.pumpWidget(button(loading: true));

        expect(tester.getSize(find.byType(AppPrimaryButton)), resting);
        expect(
          tester.getCenter(_spinner()),
          tester.getCenter(find.byType(AppPrimaryButton)),
        );
        final content = tester.widget<Visibility>(find.byType(Visibility));
        expect(content.visible, isFalse);
        if (icon == null) return;
        expect(
          find.descendant(
            of: find.byType(Visibility),
            matching: find.byType(AppIcon),
          ),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets('every size of every button is 48 high', (tester) async {
    for (final size in AppButtonSize.values) {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              AppPrimaryButton(text: 'One', size: size, onPressed: () {}),
              AppSecondaryButton(text: 'Two', size: size, onPressed: () {}),
              AppTextButton(text: 'Three', size: size, onPressed: () {}),
            ],
          ),
        ),
      );

      for (final type in [
        AppPrimaryButton,
        AppSecondaryButton,
        AppTextButton,
      ]) {
        expect(tester.getSize(find.byType(type)).height, 48, reason: '$size');
      }
    }
  });

  testWidgets('an infinite width stretches the button', (tester) async {
    await tester.pumpWidget(
      host(
        AppPrimaryButton(text: 'Go', width: double.infinity, onPressed: () {}),
      ),
    );

    expect(tester.getSize(find.byType(AppPrimaryButton)).width, 800);
  });

  testWidgets('destructive buttons use the error role', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            AppPrimaryButton(text: 'A', destructive: true, onPressed: () {}),
            AppSecondaryButton(text: 'B', destructive: true, onPressed: () {}),
            AppTextButton(text: 'C', destructive: true, onPressed: () {}),
          ],
        ),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(AppPrimaryButton)),
    ).colorScheme;

    expect(
      _styleOf(tester, AppPrimaryButton).backgroundColor!.resolve({}),
      scheme.error,
    );
    expect(
      _styleOf(tester, AppSecondaryButton).foregroundColor!.resolve({}),
      scheme.error,
    );
    expect(
      _styleOf(tester, AppTextButton).foregroundColor!.resolve({}),
      scheme.error,
    );
  });

  testWidgets('an icon button has a tooltip and a 48 target', (tester) async {
    await tester.pumpWidget(
      host(
        AppIconButton(
          icon: AppIcons.close,
          tooltip: 'Close',
          size: AppIconButtonSize.small,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppIconButton)).shortestSide,
      greaterThanOrEqualTo(48),
    );
  });
}
