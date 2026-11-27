import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/features/stats/stats.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tab_bar_clearance.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ShellHeader(
            title: Text(l10n.navStudy, style: context.text.screenTitle),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: NumerSpace.sm),
              child: NumerBlock(
                children: [
                  NumerRow(
                    title: l10n.statistics,
                    showChevron: true,
                    onTap: () => _open(context, const StatsScreen()),
                  ),
                  NumerRow(
                    title: l10n.history,
                    showChevron: true,
                    onTap: () => _open(context, const HistoryScreen()),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: tabBarClearance(context)),
          ),
        ],
      ),
    );
  }
}
