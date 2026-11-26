import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';

// content and chrome sizes that have no token
const double _iconSm = 16;
const double _iconMd = 20;
const double _iconDf = 24;
const double _avatarSm = 32;
const double _avatarMd = 40;
const double _avatarDf = 48;
const double _avatarLg = 64;
const double _avatarXl = 80;
const double _avatarXxl = 100;
const double _avatarXxxl = 120;
const double _buttonHeight = 48;
const double _dividerThin = 0.5;
const double _dividerDf = 1;
const double _dividerThick = 2;

abstract final class AppSpacing {
  static const double xs = NumerSpace.xs;
  static const double sm = NumerSpace.sm;
  static const double md = NumerSpace.md;
  static const double df = NumerSpace.lg;
  static const double lg = NumerSpace.lg;
  static const double xl = NumerSpace.xl;
  static const double xxl = NumerSpace.xxl;
  static const double xxxl = NumerSpace.xxxl;
  static const double xxxxl = NumerSpace.xxxl;

  static const EdgeInsets screenPadding = EdgeInsets.all(df);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: df,
  );
  static const EdgeInsets screenVertical = EdgeInsets.symmetric(vertical: df);
  static const EdgeInsets cardPadding = EdgeInsets.all(df);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(xl);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: df,
    vertical: md,
  );
  static const EdgeInsets listItemPaddingCompact = EdgeInsets.symmetric(
    horizontal: df,
    vertical: sm,
  );
  static const EdgeInsets listItemPaddingSpacious = EdgeInsets.symmetric(
    horizontal: df,
    vertical: df,
  );
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: df,
  );
  static const EdgeInsets buttonPaddingCompact = EdgeInsets.symmetric(
    horizontal: df,
    vertical: md,
  );
  static const EdgeInsets iconButtonPadding = EdgeInsets.all(md);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xl);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: df,
  );
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );
  static const EdgeInsets tagPadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );
  static const EdgeInsets zero = EdgeInsets.zero;

  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalDf = SizedBox(height: df);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalDf = SizedBox(width: df);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);
  static const SizedBox horizontalXxl = SizedBox(width: xxl);

  static const double radiusXs = NumerRadius.sm;
  static const double radiusSm = NumerRadius.sm;
  static const double radiusMd = NumerRadius.md;
  static const double radiusDf = NumerRadius.lg;
  static const double radiusLg = NumerRadius.xl;
  static const double radiusXl = NumerRadius.xl;
  static const double radiusRound = NumerRadius.full;

  static BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusDf => BorderRadius.circular(radiusDf);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusRound =>
      BorderRadius.circular(radiusRound);
  static BorderRadius get borderRadiusTopSheet =>
      const BorderRadius.vertical(top: Radius.circular(NumerRadius.xl));
  static BorderRadius get borderRadiusBottomSheet =>
      const BorderRadius.vertical(bottom: Radius.circular(NumerRadius.xl));

  static const double iconSm = _iconSm;
  static const double iconMd = _iconMd;
  static const double iconDf = _iconDf;
  static const double iconLg = _iconDf;
  static const double iconXl = _iconDf;

  static const double avatarSm = _avatarSm;
  static const double avatarMd = _avatarMd;
  static const double avatarDf = _avatarDf;
  static const double avatarLg = _avatarLg;
  static const double avatarXl = _avatarXl;
  static const double avatarXxl = _avatarXxl;
  static const double avatarXxxl = _avatarXxxl;

  static const double buttonHeightSm = _buttonHeight;
  static const double buttonHeightDf = _buttonHeight;
  static const double buttonHeightLg = _buttonHeight;

  static const double appBarHeight = kToolbarHeight;

  static const double dividerThin = _dividerThin;
  static const double dividerDf = _dividerDf;
  static const double dividerThick = _dividerThick;
}

abstract final class HomeRadius {
  static const double card = NumerRadius.lg;
  static const double cardLg = NumerRadius.lg;
  static const double button = NumerRadius.md;
  static const double pill = NumerRadius.full;

  static BorderRadius get cardBR => BorderRadius.circular(card);
}

abstract final class HomeShadows {
  static List<BoxShadow> get navBar => const [];
}
