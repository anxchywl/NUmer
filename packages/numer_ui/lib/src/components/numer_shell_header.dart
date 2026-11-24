import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';

const double _avatarSize = 32;
const int _maxActions = 2;

class NumerShellHeader extends StatelessWidget {
  const NumerShellHeader({
    super.key,
    required this.title,
    this.actions = const [],
    required this.avatar,
    required this.avatarTooltip,
    required this.onAvatarPressed,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget avatar;
  final String avatarTooltip;
  final VoidCallback onAvatarPressed;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= _maxActions, 'at most two actions');

    return SliverAppBar(
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: title,
      actions: [
        ...actions,
        IconButton(
          tooltip: avatarTooltip,
          onPressed: onAvatarPressed,
          icon: SizedBox.square(dimension: _avatarSize, child: avatar),
        ),
        const SizedBox(width: NumerSpace.xs),
      ],
    );
  }
}
