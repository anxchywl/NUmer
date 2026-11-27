import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// keeps the way into settings while memberships are loading or failed
class GroupsStatusView extends StatelessWidget {
  const GroupsStatusView({super.key, required Widget this.child})
    : error = null;

  const GroupsStatusView.error(Object this.error, {super.key}) : child = null;

  final Widget? child;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        ShellHeader(title: Text(l10n.groups, style: context.text.screenTitle)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: child ?? Text(l10n.errorLoadingMemberships('$error')),
          ),
        ),
      ],
    );
  }
}
