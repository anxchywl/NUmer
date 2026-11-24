import 'package:flutter/material.dart';

const int _maxActions = 2;
const int _maxTabs = 4;

class NumerModuleScaffold extends StatelessWidget {
  const NumerModuleScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    this.toolbarHeight,
    this.tabLabels,
    this.tabViews,
    this.body,
    this.floatingActionButton,
  });

  final String title;
  final List<Widget> actions;
  final double? toolbarHeight;
  final List<String>? tabLabels;
  final List<Widget>? tabViews;
  final Widget? body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    // list lengths are not constant expressions, so these cannot sit on the constructor
    assert(actions.length <= _maxActions, 'at most two actions');
    assert((body == null) != (tabLabels == null), 'give either a body or tabs');
    assert(tabLabels?.length == tabViews?.length, 'one view for each tab');
    assert((tabLabels?.length ?? 0) <= _maxTabs, 'at most four tabs');

    final labels = tabLabels;
    if (labels == null) return _scaffold(body: body!);

    return DefaultTabController(
      length: labels.length,
      child: _scaffold(
        tabBar: TabBar(tabs: [for (final label in labels) Tab(text: label)]),
        body: TabBarView(children: tabViews!),
      ),
    );
  }

  Widget _scaffold({required Widget body, TabBar? tabBar}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        toolbarHeight: toolbarHeight,
        bottom: tabBar,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
