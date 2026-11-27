import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/ai_analysis/ai_analysis.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/features/stats/stats.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tab_bar_clearance.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({
    super.key,
    required this.modules,
    required this.onOpenModule,
  });

  final List<ModuleDescriptor> modules;
  final void Function(ModuleDescriptor) onOpenModule;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final hasCourses = state.courses.isNotEmpty;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ShellHeader(
            title: Text(l10n.navStudy, style: context.text.screenTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.addCourse,
                onPressed: () => showAddCourseSheet(context),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: ActiveSessionBar()),
          ..._courses(context, hasCourses),
          SliverToBoxAdapter(child: _more(context, hasCourses)),
          SliverPadding(
            padding: EdgeInsets.only(bottom: tabBarClearance(context)),
          ),
        ],
      ),
    );
  }

  // the course list is a sliver, so this section cannot be a NumerSection
  List<Widget> _courses(BuildContext context, bool hasCourses) {
    final l10n = AppLocalizations.of(context)!;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
          child: Text(l10n.studyCoursesTitle, style: context.text.sectionTitle),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: NumerSpace.sm)),
      if (hasCourses)
        CourseListSliver(onOpenCourse: (c) => showCourseTimeSheet(context, c))
      else
        SliverToBoxAdapter(
          child: NumerEmptyState(
            message: l10n.noCoursesYet,
            actionLabel: l10n.addCourse,
            onAction: () => showAddCourseSheet(context),
            primaryAction: true,
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: NumerSpace.xl)),
    ];
  }

  Widget _more(BuildContext context, bool hasCourses) {
    final l10n = AppLocalizations.of(context)!;
    return NumerSection(
      title: l10n.studyMoreTitle,
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
          if (hasCourses)
            NumerRow(
              title: l10n.courseAnalysis,
              trailing: NumerStatusLabel(l10n.comingSoon),
              onTap: () => _open(context, const AiAnalysisScreen()),
            ),
          for (final module in modules)
            NumerRow(
              title: module.title(l10n),
              subtitle: module.subtitle(l10n),
              showChevron: true,
              onTap: () => onOpenModule(module),
            ),
        ],
      ),
    );
  }
}
