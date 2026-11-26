import 'package:flutter/material.dart';

const int _maxActions = 2;
const double _dividerHeight = 1;

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.centerTitle,
    this.bottom,
    this.showDivider = false,
    this.toolbarHeight = kToolbarHeight,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;
  final bool showDivider;
  final double toolbarHeight;

  double get _bottomHeight =>
      (bottom?.preferredSize.height ?? 0) + (showDivider ? _dividerHeight : 0);

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight + _bottomHeight);

  @override
  Widget build(BuildContext context) {
    assert((actions?.length ?? 0) <= _maxActions, 'at most two actions');
    return AppBar(
      leading:
          leading ??
          (showBackButton ? BackButton(onPressed: onBackPressed) : null),
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: false,
      title: titleWidget ?? _titleText(title),
      centerTitle: centerTitle,
      actions: actions,
      bottom: showDivider ? _dividedBottom() : bottom,
      toolbarHeight: toolbarHeight,
    );
  }

  PreferredSizeWidget _dividedBottom() {
    return PreferredSize(
      preferredSize: Size.fromHeight(_bottomHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?bottom,
          const Divider(height: _dividerHeight, thickness: _dividerHeight),
        ],
      ),
    );
  }
}

class AppSliverAppBar extends StatelessWidget {
  const AppSliverAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.centerTitle,
    this.bottom,
    this.pinned = false,
    this.toolbarHeight = kToolbarHeight,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;
  final bool pinned;
  final double toolbarHeight;

  @override
  Widget build(BuildContext context) {
    assert((actions?.length ?? 0) <= _maxActions, 'at most two actions');
    return SliverAppBar(
      leading: leading,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: false,
      title: titleWidget ?? _titleText(title),
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
      floating: true,
      snap: true,
      pinned: pinned,
    );
  }
}

Widget? _titleText(String? title) {
  if (title == null) return null;
  return Text(title, overflow: TextOverflow.ellipsis);
}
