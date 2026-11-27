import 'package:flutter/material.dart';

// the ios tab bar floats over the page, so scroll views end above it
double tabBarClearance(BuildContext context) {
  if (Theme.of(context).platform != TargetPlatform.iOS) return 24;
  final bottomInset = MediaQuery.of(context).padding.bottom;
  final navBottomOffset = bottomInset > 0 ? bottomInset * 0.38 : 4.0;
  const navHeight = 66.0;
  const extra = 12.0;
  return navHeight + navBottomOffset + extra;
}
