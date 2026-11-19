import 'package:flutter/material.dart';

bool isIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

double iosBottomNavClearance(BuildContext context) {
  final bottomInset = MediaQuery.of(context).padding.bottom;
  final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
  const navHeight = 66.0;
  const extra = 8.0;
  return navHeight + navBottomOffset + extra;
}

double iosFabBottomLift(BuildContext context) {
  // Keep pill close to nav while staying clear of overlap.
  final lift = iosBottomNavClearance(context) - 36.0;
  return lift > 0 ? lift : 0;
}

double iosTopContentClearance(BuildContext context) {
  if (!isIos(context)) return 0;
  return 12;
}

double progressBottomClearance(BuildContext context) {
  return isIos(context)
      ? iosBottomNavClearance(context)
      : MediaQuery.of(context).padding.bottom + 24;
}
