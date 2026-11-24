import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

const double _oneLineHeight = 56;
const double _twoLineHeight = 72;
const double _chevronSize = 20;

class NumerRow extends StatelessWidget {
  const NumerRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.showChevron = false,
    this.onTap,
  }) : assert(value == null || trailing == null, 'one trailing part'),
       assert(!showChevron || onTap != null, 'a chevron means it navigates');

  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: subtitle == null ? _oneLineHeight : _twoLineHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NumerSpace.lg,
              vertical: NumerSpace.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: NumerSpace.md),
                ],
                Expanded(child: _titles(context)),
                for (final part in _trailingParts(context)) ...[
                  const SizedBox(width: NumerSpace.sm),
                  part,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _trailingParts(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final value = this.value;
    final trailing = this.trailing;
    return [
      if (value != null)
        Text(value, style: context.text.body.copyWith(color: muted)),
      ?trailing,
      if (showChevron)
        Icon(Icons.chevron_right, size: _chevronSize, color: muted),
    ];
  }

  Widget _titles(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.rowTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: NumerSpace.xs),
          Text(
            subtitle,
            style: context.text.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
