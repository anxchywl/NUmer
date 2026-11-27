import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tab_bar_clearance.dart';

class CampusScreen extends StatelessWidget {
  const CampusScreen({super.key, required this.modules, required this.onOpen});

  final List<ModuleDescriptor> modules;
  final void Function(ModuleDescriptor) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ShellHeader(
            title: Text(l10n.navCampus, style: context.text.screenTitle),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: NumerSpace.sm),
              child: NumerBlock(
                children: [
                  for (final module in modules)
                    NumerRow(
                      leading: Icon(module.icon),
                      title: module.title(l10n),
                      subtitle: module.subtitle(l10n),
                      showChevron: true,
                      onTap: () => onOpen(module),
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
