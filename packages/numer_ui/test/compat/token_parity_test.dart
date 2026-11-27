import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/compat.dart';

// module layouts depend on these values, so drift must fail here
void main() {
  test('spacing stays on the four point grid', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.df,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
  });

  test('radii follow the numer scale', () {
    expect(
      [
        AppSpacing.radiusXs,
        AppSpacing.radiusSm,
        AppSpacing.radiusMd,
        AppSpacing.radiusDf,
        AppSpacing.radiusLg,
        AppSpacing.radiusXl,
        AppSpacing.radiusRound,
      ],
      [8, 8, 12, 16, 20, 20, 999],
    );
  });

  test('content sizes keep their values', () {
    expect(
      [AppSpacing.iconSm, AppSpacing.iconMd, AppSpacing.iconDf],
      [16, 20, 24],
    );
    expect([AppSpacing.iconLg, AppSpacing.iconXl], [24, 24]);
    expect(
      [
        AppSpacing.avatarSm,
        AppSpacing.avatarMd,
        AppSpacing.avatarDf,
        AppSpacing.avatarLg,
        AppSpacing.avatarXl,
        AppSpacing.avatarXxl,
        AppSpacing.avatarXxxl,
      ],
      [32, 40, 48, 64, 80, 100, 120],
    );
    expect(
      [
        AppSpacing.buttonHeightSm,
        AppSpacing.buttonHeightDf,
        AppSpacing.buttonHeightLg,
      ],
      [48, 48, 48],
    );
    expect(
      [AppSpacing.dividerThin, AppSpacing.dividerDf, AppSpacing.dividerThick],
      [0.5, 1, 2],
    );
  });
}
