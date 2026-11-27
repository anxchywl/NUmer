import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tab_bar_clearance.dart';

const int _maxRowsWithoutSearch = 8;

class CampusScreen extends StatefulWidget {
  const CampusScreen({super.key, required this.modules, required this.onOpen});

  final List<ModuleDescriptor> modules;
  final void Function(ModuleDescriptor) onOpen;

  @override
  State<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends State<CampusScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchable = widget.modules.length > _maxRowsWithoutSearch;
    // a hidden field must not keep filtering when modules are switched off
    final shown = searchable ? _matches(l10n) : widget.modules;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ShellHeader(
            title: Text(l10n.navCampus, style: context.text.screenTitle),
          ),
          if (widget.modules.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: NumerSpace.sm),
              sliver: SliverList.list(
                children: [
                  if (searchable) _searchField(l10n),
                  if (shown.isEmpty)
                    NumerEmptyState(message: l10n.campusNoMatch)
                  else
                    _rows(l10n, shown),
                ],
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: tabBarClearance(context)),
          ),
        ],
      ),
    );
  }

  List<ModuleDescriptor> _matches(AppLocalizations l10n) {
    final query = _search.text.toLowerCase();
    bool contains(String text) => text.toLowerCase().contains(query);
    return [
      for (final module in widget.modules)
        if (contains(module.title(l10n)) || contains(module.subtitle(l10n)))
          module,
    ];
  }

  Widget _searchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NumerSpace.lg,
        0,
        NumerSpace.lg,
        NumerSpace.sm,
      ),
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: l10n.campusSearchHint,
          // without a floating label material stops short of the 56 field height
          contentPadding: const EdgeInsets.symmetric(vertical: NumerSpace.lg),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.campusClearSearch,
                  onPressed: () => setState(_search.clear),
                ),
        ),
      ),
    );
  }

  Widget _rows(AppLocalizations l10n, List<ModuleDescriptor> modules) {
    return NumerBlock(
      children: [
        for (final module in modules)
          NumerRow(
            key: ValueKey(module.id),
            leading: Icon(module.icon),
            title: module.title(l10n),
            subtitle: module.subtitle(l10n),
            showChevron: true,
            onTap: () => widget.onOpen(module),
          ),
      ],
    );
  }
}
