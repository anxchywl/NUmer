import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/compat.dart';

import 'host.dart';
import 'names.dart';

Future<BuildContext> _pumpContext(
  WidgetTester tester,
  Brightness brightness,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    host(
      Builder(
        builder: (inner) {
          context = inner;
          return const SizedBox.shrink();
        },
      ),
      brightness: brightness,
    ),
  );
  return context;
}

List<Widget> _widgets() => [
  const AppPrimaryButton(text: 'Save', size: AppButtonSize.small),
  const AppSecondaryButton(text: 'Skip', size: AppButtonSize.medium),
  const AppTextButton(text: 'Close', size: AppButtonSize.large),
  const AppIconButton(
    icon: AppIcons.add,
    tooltip: 'Add',
    onPressed: null,
    size: AppIconButtonSize.small,
  ),
  const AppTextField(label: 'Name'),
  const GlobalSearchBar(hint: 'Search'),
  const AppCard(
    backgroundColor: Colors.transparent,
    borderRadius: BorderRadius.zero,
    child: AppIcon(AppIcons.flag),
  ),
  const AppLoader(),
  const AppProgressBar(progress: 0.5, label: 'Done', showPercentage: true),
];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('colours follow the ${brightness.name} scheme', (tester) async {
      final context = await _pumpContext(tester, brightness);
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final numer = theme.extension<NumerColors>()!;
      final colors = AppColors.of(context);

      expect(colorNames(colors), hasLength(48));
      expect(colors.primary, scheme.primary);
      expect(colors.white, scheme.onPrimary);
      expect(colors.surfaceDark, scheme.surfaceContainerHighest);
      expect(colors.textDisabled, scheme.onSurface.withValues(alpha: 0.38));
      expect(colors.success, numer.success);
      expect(colors.orange, numer.warning);
      expect(colors.errorLight, scheme.errorContainer);
      expect(colors.transparent, Colors.transparent);
    });
  }

  testWidgets('text styles resolve by size and weight', (tester) async {
    final context = await _pumpContext(tester, Brightness.light);
    final styles = AppTextStyles.of(context);
    final text = context.text;
    final scheme = Theme.of(context).colorScheme;

    expect(textStyleNames(styles), hasLength(33));
    expect(styles.displayLarge, text.display);
    expect(styles.amount, text.display);
    expect(styles.titleLarge, text.screenTitle);
    expect(styles.appBarTitle, text.sectionTitle);
    expect(styles.bodyLarge, text.rowTitle);
    expect(styles.bodyMedium, text.body);
    expect(styles.labelSmall, text.meta);
    expect(styles.button, Theme.of(context).textTheme.labelLarge);
    expect(styles.link.color, scheme.primary);
    expect(styles.error.color, scheme.error);
  });

  test('spacing, radii and home tokens resolve to numer tokens', () {
    expect(spacingNames(), hasLength(82));
    expect(AppSpacing.df, NumerSpace.lg);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.xxxxl, NumerSpace.xxxl);
    expect(AppSpacing.radiusRound, NumerRadius.full);
    expect(AppSpacing.appBarHeight, kToolbarHeight);
    expect(HomeRadius.card, NumerRadius.lg);
    expect(HomeShadows.navBar, isEmpty);
  });

  test('icons resolve to material glyphs', () {
    expect(iconNames.map((icon) => icon.asIconData), everyElement(isNotNull));
    expect(AppIcons.whatsapp.asIconData, Icons.chat_outlined);
    expect(AppIcons.flag.asIconData, Icons.flag_outlined);
    expect(iconNames, hasLength(121));
    expect(AppIcons.clockHours, hasLength(12));
  });

  testWidgets('every carried widget builds', (tester) async {
    await tester.pumpWidget(
      host(SingleChildScrollView(child: Column(children: _widgets()))),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: NumerTheme.build(seed: seed, brightness: Brightness.light),
        home: const Scaffold(
          appBar: AppAppBar(title: 'Title', showDivider: true),
          body: CustomScrollView(slivers: [AppSliverAppBar(title: 'Sliver')]),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Sliver'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a toast shows its message', (tester) async {
    final context = await _pumpContext(tester, Brightness.light);

    AppToast.showSuccess(context, 'Saved');
    AppToast.showInfo(context, 'Noted');
    AppToast.showWarning(context, 'Careful');
    AppToast.showError(context, 'Failed');
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
  });
}
