import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/news/news.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'course_picker_sheet.dart';
import 'streak_title.dart';
import 'today_block.dart';
import 'upcoming_section.dart';

const _shownNews = 5;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenStudy,
    required this.onOpenHabits,
    required this.openUpcoming,
    required this.openInModule,
  });

  final VoidCallback onOpenStudy;
  final VoidCallback onOpenHabits;
  final bool Function(BuildContext, UpcomingItem) openUpcoming;
  final bool Function(BuildContext, FeedItem) openInModule;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SyncService _sync;
  late Stream<List<Habit>> _habits;

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncService>();
    _habits = _watchHabits();
    _sync.addAfterPullListener(_reloadHabits);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FeedRepository>().refresh();
    });
  }

  @override
  void dispose() {
    _sync.removeAfterPullListener(_reloadHabits);
    super.dispose();
  }

  Stream<List<Habit>> _watchHabits() {
    final uid = context.read<AuthController>().currentUser?.uid ?? '';
    return context.read<HabitService>().habitsStream(uid);
  }

  // a pull writes habits to hive without telling an open stream
  Future<void> _reloadHabits() async {
    if (!mounted) return;
    setState(() {
      _habits = _watchHabits();
    });
  }

  Future<void> _pull() => Future.wait([
    context.read<SyncService>().syncNow(force: true),
    context.read<FeedRepository>().refresh(force: true),
  ]);

  double _iosBottomNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const navHeight = 66.0;
    const extra = 8.0;
    return navHeight + navBottomOffset + extra;
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      body: RefreshIndicator(
        // starts below the pinned header
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: _pull,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const ShellHeader(title: StreakTitle()),
            SliverToBoxAdapter(child: _syncLine(context)),
            const SliverToBoxAdapter(
              child: Column(
                children: [
                  FirstRunCreditsGate(),
                  AutoFinishWatcher(),
                  ActiveSessionBar(),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _today(context)),
            SliverToBoxAdapter(
              child: UpcomingSection(
                uid: context.select<AuthController, String>(
                  (auth) => auth.currentUser?.uid ?? '',
                ),
                openInModule: widget.openUpcoming,
              ),
            ),
            SliverToBoxAdapter(child: _news(context)),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: isIos
                    ? _iosBottomNavClearance(context)
                    : MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncLine(BuildContext context) {
    final sync = context.watch<SyncService>();
    final l10n = AppLocalizations.of(context)!;
    final String message;
    // a failed sync also reports offline
    if (sync.lastError != null) {
      message = l10n.homeSyncFailed;
    } else if (sync.status == SyncStatus.offline) {
      message = l10n.homeOffline;
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(
        left: NumerSpace.lg,
        right: NumerSpace.lg,
        bottom: NumerSpace.sm,
      ),
      child: Text(message, style: context.text.meta),
    );
  }

  Widget _news(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NumerSection(
      title: l10n.newsTitle,
      actionLabel: l10n.newsAll,
      onAction: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => NewsScreen(openInModule: widget.openInModule),
        ),
      ),
      child: NewsStates(
        limit: _shownNews,
        onOpen: (item) => openNewsItem(context, item, widget.openInModule),
      ),
    );
  }

  Widget _today(BuildContext context) {
    final running = context.select<AppState, bool>(
      (state) => state.hasAnyActiveSession,
    );
    return NumerSection(
      title: AppLocalizations.of(context)!.today,
      child: Column(
        children: [
          TodayBlock(
            habits: _habits,
            onOpenStudy: widget.onOpenStudy,
            onOpenHabits: widget.onOpenHabits,
          ),
          if (!running) ...[
            const SizedBox(height: NumerSpace.md),
            const _StudyButton(),
          ],
        ],
      ),
    );
  }
}

class _StudyButton extends StatelessWidget {
  const _StudyButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final courses = context.watch<AppState>().courses;
    final lastId = context.watch<LastCourseStore>().id;
    final last = courses.where((course) => course.id == lastId).firstOrNull;
    final (label, onPressed) = switch (last) {
      _ when courses.isEmpty => (
        l10n.addCourse,
        () => showAddCourseSheet(context),
      ),
      final Course course => (
        l10n.homeContinueCourse(course.name),
        () => showCourseTimeSheet(context, course),
      ),
      null => (l10n.homeStartSession, () => showCoursePickerSheet(context)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
