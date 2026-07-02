import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numer_app/app_state.dart';
import 'package:numer_app/models.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/sync_service.dart';

import 'package:numer_app/screens/ai_analysis_screen.dart';
import 'package:numer_app/widgets/color_picker_button.dart';
import 'package:numer_app/widgets/swipeable_course_item.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/widgets/app_toast.dart';


Future<void> showCourseTimeSheet(BuildContext context, Course course) {
  final appState = context.read<AppState>();
  appState.setCourseSheetOpen(true);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final isIos = Theme.of(context).platform == TargetPlatform.iOS;
      return FractionallySizedBox(
        heightFactor: isIos ? 0.85 : 0.8,
        child: _CourseTimeMenu(course: course),
      );
    },
  ).whenComplete(() => appState.setCourseSheetOpen(false));
}

const _colorChoices = <Color>[
  Color(0xFFEF4444), // Red
  Color(0xFFF97316), // Orange
  Color(0xFFFACC15), // Yellow
  Color(0xFF22C55E), // Green
  Color(0xFF3B82F6), // Blue
  Color(0xFF6366F1), // Indigo
  Color(0xFF8B5CF6), // Violet
  Color(0xFF84CC16), // Lime
  Color(0xFF14B8A6), // Teal
  Color(0xFF06B6D4), // Cyan
  Color(0xFFA855F7), // Purple
  Color(0xFFD946EF), // Magenta
  Color(0xFFEC4899), // Pink
];

const int _kMaxSecs = 10800; 

const int _kDefaultSemesterWeeks = 14; 



double _hoursPerCreditForLevel(int level) {
  switch (level) {
    case 1:
      return 3.0;
    case 2:
      return 2.5;
    case 3:
      return 2.0;
    case 4:
      return 1.5;
    case 5:
      return 1.0;
    default:
      return 2.0;
  }
}

String _expShortLabel(BuildContext context, int level) {
  switch (level) {
    case 1:
      return AppLocalizations.of(context)!.expLevel1;
    case 2:
      return AppLocalizations.of(context)!.expLevel2;
    case 3:
      return AppLocalizations.of(context)!.expLevel3;
    case 4:
      return AppLocalizations.of(context)!.expLevel4;
    case 5:
      return AppLocalizations.of(context)!.expLevel5;
    default:
      return AppLocalizations.of(context)!.expLevelDefault;
  }
}

String _fmtHours(double h, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final whole = h.floor();
  final mins = ((h - whole) * 60).round();
  if (mins == 0) return '$whole${l10n.hUnit}';
  return '$whole${l10n.hUnit} $mins${l10n.mUnit}';
}

String _fmtHMS(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}

String _courseNameWithoutParentheses(String value) {
  return value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
}


// _savedSnack removed


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _fabVisible = true;

  bool _isIos(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  double _iosBottomNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const navHeight = 66.0;
    const extra = 8.0;
    return navHeight + navBottomOffset + extra;
  }

  double _iosFabBottomLift(BuildContext context) {
    // Keep pills just above the floating nav, accounting for FAB's own float margin.
    final lift = _iosBottomNavClearance(context) - 36.0;
    return lift > 0 ? lift : 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;



    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse && _fabVisible) {
            setState(() => _fabVisible = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_fabVisible) {
            setState(() => _fabVisible = true);
          }
          return false;
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            title: const _StreakTitle(),
            centerTitle: false, // Ensure title is left-aligned on iOS
            actions: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: _SyncStatusChip(),
                ),
              ),
            ],
          ),
          const SliverToBoxAdapter(
            child: Column(
              children: [
                _FirstRunCreditsGate(),
                _AutoFinishWatcher(),
                _ActiveSessionBar(),
              ],
            ),
          ),
          if (courses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: _isIos(context)
                    ? _IosLiquidActionPill(
                        icon: Icons.add,
                        label: AppLocalizations.of(context)!.addCourse,
                        onPressed: () => _openAddCourse(context),
                      )
                    : FilledButton.icon(
                        onPressed: () => _openAddCourse(context),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.addCourse),
                      ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverReorderableList(
                itemCount: courses.length,
                onReorder: (oldIndex, newIndex) =>
                    state.reorderCourses(oldIndex, newIndex),
                itemBuilder: (context, i) {
                  final c = courses[i];

                  return Padding(
                    key: ValueKey(c.id),
                    padding:
                        EdgeInsets.only(bottom: i == courses.length - 1 ? 0 : 8),
                    child: ReorderableDelayedDragStartListener(
                      index: i,
                      child: SwipeableCourseItem(
                        confirmDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(AppLocalizations.of(context)!.deleteCourseTitle),
                              content: Text(
                                  AppLocalizations.of(context)!.deleteCourseMessage),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(AppLocalizations.of(context)!.cancel),
                                ),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pop(context, true),
                                  icon: const Icon(Icons.delete),
                                  label: Text(AppLocalizations.of(context)!.delete),
                                ),
                              ],
                            ),
                          );
                          return ok == true;
                        },
                        onDelete: () => state.removeCourse(c.id),
                        child: Builder(
                          builder: (context) {
                            final showSummary = state.homeSummaryRange != HomeSummaryRange.off;
                            final showProgress = state.progressView != ProgressView.off;
                            final customGoalHours =
                                state.goalHoursForCourse(c.id) ?? 0;
                            final hasCredits = (c.credits ?? 0) > 0;
                            final willShowProgressBar =
                                showProgress && (hasCredits || customGoalHours > 0);
                            final isMinimal = !showSummary && !willShowProgressBar;

                            if (isMinimal) {
                              final courseTheme = Theme.of(context);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: CircleAvatar(backgroundColor: c.color),
                                title: Text(
                                  c.name,
                                  style: courseTheme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(Icons.more_horiz, color: courseTheme.colorScheme.onSurfaceVariant),
                                onTap: () => _openCourseTimeMenu(context, c),
                              );
                            }

                            return ListTile(
                              leading: CircleAvatar(backgroundColor: c.color),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if ((c.credits ?? 0) > 0 && showProgress)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: _CreditsBadge(
                                        credits: c.credits!,
                                        onTap: () => _openCreditsPopup(context, c),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Builder(
                                builder: (context) {
                                  final showProgressBar =
                                      hasCredits || customGoalHours > 0;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (showSummary)
                                        FutureBuilder<Map<String, int>>(
                                          future:
                                              _loadCourseSeconds(context, c.id),
                                          builder: (context, snap) {
                                            final secs = snap.data?[c.id] ?? 0;
                                            final label =
                                                state.homeSummaryLabel(context);
                                            return Text('$label: ${_fmtHMS(secs)}');
                                          },
                                        ),
                                      if (showProgressBar && showProgress)
                                        FutureBuilder<int>(
                                          future:
                                              state.progressView == ProgressView.day
                                                  ? Future<int>.value(
                                                      state.todaySecondsFor(c.id),
                                                    )
                                                  : _weeklyElapsedForCourse(
                                                      context, c.id),
                                          builder: (context, snap) {
                                            final elapsed =
                                                (snap.data ?? 0); 
                                            final level = c.expLevel ?? 3;
                                            final weeklyHoursGoal =
                                                customGoalHours > 0
                                                    ? customGoalHours
                                                    : hasCredits
                                                        ? c.credits! *
                                                            _hoursPerCreditForLevel(
                                                                level)
                                                        : 0;
                                            if (weeklyHoursGoal <= 0) {
                                              return const SizedBox.shrink();
                                            }
                                            final weeklyGoalSecs =
                                                (weeklyHoursGoal * 3600)
                                                    .clamp(1, 1 << 31)
                                                    .toInt();
                                            final targetSecs = state.progressView ==
                                                    ProgressView.day
                                                ? (weeklyGoalSecs / 7)
                                                    .round()
                                                    .clamp(1, 1 << 31)
                                                : weeklyGoalSecs;
                                            final progress = targetSecs <= 0
                                                ? 0.0
                                                : (elapsed / targetSecs)
                                                    .clamp(0.0, 1.0);
                                            final labelPrefix =
                                                state.progressView ==
                                                        ProgressView.day
                                                    ? AppLocalizations.of(context)!.dailyGoal
                                                    : AppLocalizations.of(context)!.weeklyGoal;
                                            final targetHoursLabel =
                                                state.progressView ==
                                                        ProgressView.day
                                                    ? (weeklyHoursGoal / 7)
                                                        .toStringAsFixed(1)
                                                    : weeklyHoursGoal
                                                        .toStringAsFixed(1);
    
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TweenAnimationBuilder<double>(
                                                    duration: const Duration(
                                                        milliseconds: 350),
                                                    curve: Curves.easeOutCubic,
                                                    tween: Tween(
                                                        begin: 0, end: progress),
                                                    builder: (context, v, _) {
                                                      return ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                6),
                                                        child:
                                                            LinearProgressIndicator(
                                                          value: v,
                                                          minHeight: 8,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$labelPrefix: ${_fmtHMS(elapsed)} / $targetHoursLabel${AppLocalizations.of(context)!.hUnit}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                            color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  );
                                },
                              ),
                              trailing: const Icon(Icons.more_horiz),
                              onTap: () => _openCourseTimeMenu(context, c),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: _isIos(context)
                  ? _iosBottomNavClearance(context)
                  : MediaQuery.of(context).padding.bottom + 80,
            ),
          ),
        ]),
      ),
      floatingActionButton: courses.isEmpty
          ? null
          : _isIos(context)
              ? AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutQuart,
                  offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutQuart,
                    opacity: _fabVisible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_fabVisible,
                      child: Padding(
                        padding:
                            EdgeInsets.only(bottom: _iosFabBottomLift(context)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _IosLiquidActionPill(
                              icon: Icons.auto_awesome_outlined,
                              iconOnly: true,
                              iconSize: 24,
                              iconPadding: const EdgeInsets.all(13),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AiAnalysisScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _IosLiquidActionPill(
                              icon: Icons.add,
                              label: AppLocalizations.of(context)!.addCourse,
                              onPressed: () => _openAddCourse(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutQuart,
                  offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutQuart,
                    opacity: _fabVisible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_fabVisible,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'ai-fab',
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            elevation: 4,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AiAnalysisScreen(),
                                ),
                              );
                            },
                            child: const Icon(Icons.auto_awesome_outlined),
                          ),
                          const SizedBox(height: 16),
                          FloatingActionButton(
                            heroTag: 'add-fab',
                            onPressed: () => _openAddCourse(context),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

    );
  }

  void _openAddCourse(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddCourseSheet(),
    );
  }

  void _openCourseTimeMenu(BuildContext context, Course course) {
    showCourseTimeSheet(context, course);
  }

  Future<Map<String, int>> _loadCourseSeconds(
      BuildContext context, String id) async {
    final state = context.read<AppState>();
    final (start, end) = state.homeSummaryBoundsNow();
    final s = state;
    final bounds = (start, end);
    final map = await s.secondsByCourseBetween(bounds.$1, bounds.$2);
    return {id: map[id] ?? 0};
  }
}

class _IosLiquidActionPill extends StatelessWidget {
  const _IosLiquidActionPill({
    required this.icon,
    required this.onPressed,
    this.label,
    this.iconOnly = false,
    this.iconSize = 18,
    this.iconPadding,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final bool iconOnly;
  final double iconSize;
  final EdgeInsetsGeometry? iconPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black.withValues(alpha: 0.88);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.11 : 0.22),
                Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.24),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.035),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: iconOnly
                    ? (iconPadding ?? const EdgeInsets.all(12))
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: iconOnly
                    ? Icon(icon, size: iconSize, color: fg)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: iconSize, color: fg),
                          const SizedBox(width: 8),
                          Text(
                            label ?? '',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color background;
    Color foreground;
    IconData icon;
    String label;

    switch (sync.status) {
      case SyncStatus.offline:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.cloud_off;
        label = AppLocalizations.of(context)!.syncOffline;
        break;
      case SyncStatus.syncing:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.sync;
        label = AppLocalizations.of(context)!.syncSyncing;
        break;
      case SyncStatus.upToDate:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.cloud_done;
        label = AppLocalizations.of(context)!.syncUpToDate;
        break;
    }

    final tooltip = sync.lastError;

    final chip = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );

    return tooltip == null
        ? chip
        : Tooltip(message: tooltip, child: chip);
  }
}

class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet();

  @override
  State<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<_AddCourseSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Color _picked = _colorChoices.first;

  final _credits = TextEditingController();
  int _expLevel = 3;

  bool _showCustomPicker = false;

  bool get _hasCredits {
    final v = double.tryParse(_credits.text.trim());
    return v != null && v > 0;
  }

  @override
  void initState() {
    super.initState();
    _credits.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    
    final pad = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      left: 16,
      right: 16,
      top: 16,
    );

    return Padding(
      padding: pad,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.addCourse, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.courseName,
                  hintText: AppLocalizations.of(context)!.courseNameHint,
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(32),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\p{L}\p{N} ]', unicode: true),
                  ),
                ],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.required : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.color,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  
                  for (final c in _colorChoices.take(13))
                    GestureDetector(
                      onTap: () => setState(() {
                        _picked = c;
                        _showCustomPicker = false;
                      }),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _picked.toARGB32() == c.toARGB32()
                              ? Border.all(width: 3, color: Colors.black54)
                              : null,
                        ),
                      ),
                    ),
                  ColorPickerButton(
                    color: _picked,
                    onCustomTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _showCustomPicker = !_showCustomPicker);
                    },
                    onColorPicked: (color) => setState(() => _picked = color),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _showCustomPicker
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    CustomColorPicker(
                      initial: _picked,
                      onChanged: (c) => setState(() => _picked = c),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _credits,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final val = double.tryParse(v);
                  if (val == null) return 'Invalid number'; 
                  if (val > 64) return 'Max 64';
                  return null;
                },
                inputFormatters: [
                  LengthLimitingTextInputFormatter(2),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.creditsOptional,
                  hintText: AppLocalizations.of(context)!.creditsHint,
                  helperText: AppLocalizations.of(context)!.creditsHelper,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _hasCredits
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context)!.experienceLevel,
                        style: Theme.of(context).textTheme.labelLarge),
                    Slider(
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_expLevel',
                      value: _expLevel.toDouble(),
                      onChanged: (v) => setState(() => _expLevel = v.round()),
                    ),
                    Text(
                      '${_expShortLabel(context, _expLevel)} ',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;

                  final id =
                      '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
                  final creditsVal = double.tryParse(_credits.text.trim());
                  final course = Course(
                    id: id,
                    name: _name.text.trim(),
                    day: 'Mon',
                    start: '09:00',
                    end: '10:00',
                    colorValue: _picked.toARGB32(),
                    credits: creditsVal,
                    expLevel: _hasCredits ? _expLevel : null,
                  );

                  final appState =
                      context.read<AppState>(); 
                  final navigator =
                      Navigator.of(context); 

                  await appState.addCourse(course);

                  if (!mounted) return; 
                  navigator.pop(); 
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int> _weeklyElapsedForCourse(BuildContext context, String id) async {
  final s = context.read<AppState>();
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final offset = s.weekStart == WeekStart.monday
      ? (midnight.weekday - DateTime.monday).clamp(0, 6)
      : (midnight.weekday % 7);
  final DateTime weekStart = midnight.subtract(Duration(days: offset));
  final DateTime weekEnd = weekStart.add(const Duration(days: 7));
  final map = await s.secondsByCourseBetween(weekStart, weekEnd);
  return map[id] ?? 0;
}

void _openCreditsPopup(BuildContext context, Course c) async {
  final appState = context.read<AppState>();
  final savedGoal = appState.goalHoursForCourse(c.id);
  final level = c.expLevel ?? 3;
  final perCred = _hoursPerCreditForLevel(level);
  final credits = c.credits!;
  final defaultWeekly = credits * perCred;
  final weekly = savedGoal ?? defaultWeekly;



  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      double customWeekly = weekly;
      final sliderMin = math.min(defaultWeekly * 0.5, customWeekly);
      final sliderMax = math.max(defaultWeekly * 1.5, customWeekly);
      final tt = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;

      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final semester = customWeekly * _kDefaultSemesterWeeks;
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.setGoals, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Course Info
                Row(
                  children: [
                    CircleAvatar(backgroundColor: c.color, radius: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _expShortLabel(context, level),
                        style: tt.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Stats Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      _popupRow(AppLocalizations.of(context)!.semester(_kDefaultSemesterWeeks), _fmtHours(semester, context)),
                       Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      _popupRow(AppLocalizations.of(context)!.targetPerWeek, _fmtHours(customWeekly, context), isBold: true),
                       Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      _popupRow(AppLocalizations.of(context)!.targetPerDay, _fmtHours(customWeekly / 7, context)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Slider
                Text(AppLocalizations.of(context)!.adjustWeeklyGoal, style: tt.labelLarge?.copyWith(color: scheme.primary)),
                const SizedBox(height: 8),
                Text(
                     AppLocalizations.of(context)!.hPerWeek(customWeekly.toStringAsFixed(1)), 
                     style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                     textAlign: TextAlign.center,
                ),
                Slider(
                  min: sliderMin,
                  max: sliderMax,
                  divisions: ((sliderMax - sliderMin) * 2).round(), // 0.5 steps
                  value: customWeekly,
                  onChanged: (v) => setLocal(() => customWeekly = v),
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final l10n = AppLocalizations.of(context)!;
                    await appState.setCourseGoalHours(c.id, customWeekly);
                    
                    if (!navigator.mounted) return;
                    navigator.pop();
                    showAppMessage(navigator.context, l10n.goalsUpdated);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(AppLocalizations.of(context)!.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _popupRow(String label, String value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
             color: Colors.grey.shade600, 
             fontSize: 14,
             fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          )
        ),
        Text(
          value, 
          style: TextStyle(
             fontSize: 15,
             fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          )
        ),
      ],
    ),
  );
}

class _CreditsBadge extends StatelessWidget {
  final double credits;
  final VoidCallback onTap;
  const _CreditsBadge({required this.credits, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bg = t.colorScheme.surfaceContainerHighest.withAlpha((0.7 * 255).round());
    final fg = t.colorScheme.onSurface.withAlpha((0.9 * 255).round());
    final text = credits == 1
        ? '1 ${AppLocalizations.of(context)!.credits}'
        : '${credits % 1 == 0 ? credits.toInt() : credits.toStringAsFixed(1)} ${AppLocalizations.of(context)!.credits_plural}';

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: t.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstRunCreditsGate extends StatefulWidget {
  const _FirstRunCreditsGate();

  @override
  State<_FirstRunCreditsGate> createState() => _FirstRunCreditsGateState();
}

class _FirstRunCreditsGateState extends State<_FirstRunCreditsGate> {
  bool _ran = false;
  bool _checking = false;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    _appState.addListener(_handleStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _handleStateChange() {
    if (!_ran) {
      _maybeShow();
    }
  }

  @override
  void dispose() {
    _appState.removeListener(_handleStateChange);
    super.dispose();
  }

  Future<void> _maybeShow() async {
    if (!mounted || _ran || _checking) return;
    if (_appState.requiresProfileSetup) return;
    if (!_appState.hasProfile) return;
    if (_appState.courses.isNotEmpty) {
      _ran = true;
      return;
    }

    _checking = true;
    try {
      final pendingAddCourse = await Storage.getPendingCoursePrompt();
      final prefs = await SharedPreferences.getInstance();

      if (pendingAddCourse) {
        _ran = true;
        if (!mounted) return;
        await _openAddCourseSheet();
        await Storage.setPendingCoursePrompt(false);
        await prefs.setBool('onboarded_credits_v1', true);
        return;
      }

      _ran = true;
      await prefs.setBool('onboarded_credits_v1', true);
      return;
    } finally {
      _checking = false;
    }
  }

  Future<void> _openAddCourseSheet() {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddCourseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}


class _AutoFinishWatcher extends StatefulWidget {
  const _AutoFinishWatcher();

  @override
  State<_AutoFinishWatcher> createState() => _AutoFinishWatcherState();
}

class _AutoFinishWatcherState extends State<_AutoFinishWatcher> {
  Timer? _ticker;
  String? _activeId; 
  int? _plannedSecs; 

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final state = context.read<AppState>();

      
      final timerEntry = state.timerRunning.entries.firstWhere(
        (e) => e.value == true,
        orElse: () => const MapEntry<String, bool>('', false),
      );
      final swEntry = state.stopwatchRunning.entries.firstWhere(
        (e) => e.value == true,
        orElse: () => const MapEntry<String, bool>('', false),
      );
      final pomoEntry = state.pomodoroRunning.entries.firstWhere(
        (e) => e.value == true,
        orElse: () => const MapEntry<String, bool>('', false),
      );

      String? kind; 
      String? id;
      if (timerEntry.value == true) {
        kind = 'timer';
        id = timerEntry.key;
      } else if (swEntry.value == true) {
        kind = 'stopwatch';
        id = swEntry.key;
      } else if (pomoEntry.value == true) {
        kind = 'pomodoro';
        id = pomoEntry.key;
      }

      
      if (kind == null || id == null) {
        _activeId = null;
        _plannedSecs = null;
        return;
      }

      
      if (_activeId != id) {
        _activeId = id;
        _plannedSecs = null;
        if (kind == 'timer') {
          final p = await SharedPreferences.getInstance();
          _plannedSecs = p.getInt('timer_planned_$id');
        }
      }

      
      final courseName = state.courses
          .firstWhere(
            (c) => c.id == id,
            orElse: () => Course(
              id: id!,
              name: 'Course',
              day: '',
              start: '',
              end: '',
              colorValue: 0xFF94A3B8,
            ),
          )
          .name;

      
      if (kind == 'timer') {
        final elapsed = state.currentElapsedTimer(id).inSeconds;
        if (_plannedSecs != null &&
            _plannedSecs! > 0 &&
            elapsed >= _plannedSecs!) {
          
          
          final start = state.timerStart[id];
          DateTime? forcedEnd;
          if (start != null) {
            forcedEnd = start.add(Duration(seconds: _plannedSecs!));
          }

          await state.stopTimer(id, forcedEnd: forcedEnd);
          final p = await SharedPreferences.getInstance();
          await p.remove('timer_planned_$id');

          if (!mounted) return; 
          showAppMessage(
            context,
            AppLocalizations.of(context)!.timeSavedMessage(
              _courseNameWithoutParentheses(courseName),
            ),
          );
          _activeId = null;
          _plannedSecs = null;
        }
      } else if (kind == 'stopwatch') {
        final e = state.currentElapsedStopwatch(id).inSeconds;
        if (e >= _kMaxSecs) {
          await state.stopStopwatch(id);

          if (!mounted) return; 
          showAppMessage(
            context,
            AppLocalizations.of(context)!.timeSavedMessage(
              _courseNameWithoutParentheses(courseName),
            ),
          );
          _activeId = null;
          _plannedSecs = null;
        }
      } else if (kind == 'pomodoro') {
        
      }

      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}



class _ActiveSessionBar extends StatefulWidget {
  const _ActiveSessionBar();

  @override
  State<_ActiveSessionBar> createState() => _ActiveSessionBarState();
}

class _ActiveSessionBarState extends State<_ActiveSessionBar> {
  Timer? _ticker;
  String? _cachedCourseId;
  int? _plannedSecs; 

  @override
  void initState() {
    super.initState();
    
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPlannedIfNeeded(String courseId) async {
    if (_cachedCourseId == courseId) return;
    _cachedCourseId = courseId;
    final prefs = await SharedPreferences.getInstance();
    _plannedSecs = prefs.getInt('timer_planned_$courseId');
    if (mounted) setState(() {});
  }

  String _fmtHMSLocal(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  bool _hasAnyActive(AppState s) =>
      s.timerRunning.values.any((v) => v == true) ||
      s.stopwatchRunning.values.any((v) => v == true) ||
      s.pomodoroRunning.values.any((v) => v == true);

  ({String kind, String id})? _activeInfo(AppState s) {
    final t = s.timerRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (t.value == true) return (kind: 'timer', id: t.key);
    final p = s.pomodoroRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (p.value == true) return (kind: 'pomodoro', id: p.key);
    final sw = s.stopwatchRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (sw.value == true) return (kind: 'stopwatch', id: sw.key);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_hasAnyActive(state)) {
      return const SizedBox.shrink();
    }

    final info = _activeInfo(state)!;
    final courseId = info.id;
    final kind = info.kind;
    final course = state.courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => Course(
        id: courseId,
        name: 'Unknown',
        day: '',
        start: '',
        end: '',
        colorValue: 0xFF94A3B8,
      ),
    );

    if (kind == 'timer') {
      _loadPlannedIfNeeded(courseId);
    } else {
      _plannedSecs = null;
      _cachedCourseId = null;
    }

    String timeText;
    String subtitleKind;
    if (kind == 'timer') {
      final elapsed = state.currentElapsedTimer(courseId).inSeconds;
      if (_plannedSecs != null && _plannedSecs! > 0) {
        final remaining = (_plannedSecs! - elapsed).clamp(0, _kMaxSecs);
        timeText = '${_fmtHMSLocal(remaining)} remaining';
      } else {
        timeText = '${_fmtHMSLocal(elapsed)} elapsed';
      }
      subtitleKind = 'Timer';
    } else if (kind == 'stopwatch') {
      final elapsed = state.currentElapsedStopwatch(courseId).inSeconds;
      timeText = _fmtHMSLocal(elapsed);
      subtitleKind = 'Stopwatch';
    } else {
      final remaining = state.currentPomodoroRemaining(courseId).inSeconds;
      final phase = state.pomodoroPhase[courseId] ?? PomodoroPhase.work;
      final paused = state.pomodoroPaused[courseId] ?? false;
      timeText =
          '${_pomodoroPhaseLabel(phase)} • ${_fmtHMSLocal(remaining)} remaining${paused ? ' (paused)' : ''}';
      subtitleKind = 'Pomodoro';
    }

    final theme = Theme.of(context);
    final bg = theme.colorScheme.primaryContainer;
    final fg = theme.colorScheme.onPrimaryContainer;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Material(
        key: ValueKey('$courseId-$kind'),
        color: bg,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: course.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitleKind • $timeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context); 
                
                int seconds = 0;
                String? snackMessage; 

                if (kind == 'timer') {
                  
                  
                  snackMessage = AppLocalizations.of(context)!.timeSavedMessage(
                    _courseNameWithoutParentheses(course.name),
                  );
                  seconds = await state.stopTimer(courseId);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('timer_planned_$courseId');
                } else if (kind == 'stopwatch') {
                  snackMessage = AppLocalizations.of(context)!.timeSavedMessage(
                    _courseNameWithoutParentheses(course.name),
                  );
                  seconds = await state.stopStopwatch(courseId);
                } else {
                  await state.resetPomodoro(courseId);
                  snackMessage =
                      'Pomodoro for "${_courseNameWithoutParentheses(course.name)}" reset.';
                }

                if (kind != 'pomodoro' && seconds > 0) { 
                   // Global listener handles reflection now
                }
                
                if (messenger.mounted) {
                  showAppMessage(navigator.context, snackMessage);
                }
              },
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  kind == 'timer'
                      ? 'Done'
                      : (kind == 'stopwatch' ? 'Stop' : 'Reset'),
                ),
              )
            ],
          ),
        ),
      ),
    );
}

  String _pomodoroPhaseLabel(PomodoroPhase phase) {
    final l10n = AppLocalizations.of(context)!;
    switch (phase) {
      case PomodoroPhase.work:
        return l10n.work;
      case PomodoroPhase.shortBreak:
        return l10n.shortBreak;
      case PomodoroPhase.longBreak:
        return l10n.longBreak;
    }
  }
}



class _CourseTimeMenu extends StatefulWidget {
  final Course course;
  const _CourseTimeMenu({required this.course});

  @override
  State<_CourseTimeMenu> createState() => _CourseTimeMenuState();
}

class _CourseTimeMenuState extends State<_CourseTimeMenu>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;

  
  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  final _hNode = FocusNode();
  final _mNode = FocusNode();
  final _sNode = FocusNode();

  
  Timer? _ticker;

  
  bool _kbOpen = false;

  
  late final AnimationController _kbCtrl;
  late final Animation<Offset> _inputSlide;
  late final Animation<double> _fadeAway;
  late final Animation<Offset> _timerSlide;

  double? _pendingLongBreak;
  int _lastSettledTab = 0;
  bool _restoringTab = false;

  
  String get _plannedKey => 'timer_planned_${widget.course.id}';
  Future<void> _savePlannedSecs(int secs) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_plannedKey, secs);
  }

  Future<int?> _loadPlannedSecs() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_plannedKey);
  }

  Future<void> _clearPlannedSecs() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_plannedKey);
  }

  
  bool _hasAnyActive(AppState s) =>
      s.timerRunning.values.any((v) => v == true) ||
      s.stopwatchRunning.values.any((v) => v == true) ||
      s.pomodoroRunning.values.any((v) => v == true);

  ({String kind, String id})? _activeInfo(AppState s) {
    final t = s.timerRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (t.value == true) return (kind: 'timer', id: t.key);
    final p = s.pomodoroRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (p.value == true) return (kind: 'pomodoro', id: p.key);
    final sw = s.stopwatchRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    if (sw.value == true) return (kind: 'stopwatch', id: sw.key);
    return null;
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    int initialIndex = 0;
    if (state.pomodoroRunning[widget.course.id] == true ||
        state.pomodoroPaused[widget.course.id] == true) {
      initialIndex = 2;
    } else if (state.stopwatchRunning[widget.course.id] == true) {
      initialIndex = 1;
    } else if (state.timerRunning[widget.course.id] == true) {
      initialIndex = 0;
    }

    _tabs = TabController(length: 3, vsync: this, initialIndex: initialIndex)
      ..addListener(_handleTabChange);
    _lastSettledTab = initialIndex;

    _kbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _inputSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.20),
    ).animate(CurvedAnimation(parent: _kbCtrl, curve: Curves.easeOutCubic));
    _fadeAway = CurvedAnimation(
      parent: _kbCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _timerSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.20),
    ).animate(CurvedAnimation(parent: _kbCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addObserver(this);

    _hNode.addListener(_handleFocusChange);
    _mNode.addListener(_handleFocusChange);
    _sNode.addListener(_handleFocusChange);

    
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final state = context.read<AppState>();

      
      final planned = await _loadPlannedSecs();
      final isThisTimerRunning =
          (state.timerRunning[widget.course.id] ?? false);
      if (planned != null && isThisTimerRunning) {
        final elapsed = state.currentElapsedTimer(widget.course.id).inSeconds;
        final remaining = planned - elapsed;
        if (remaining <= 0) {
          await state.stopTimer(widget.course.id);
          await _clearPlannedSecs();
          if (!mounted) return;
          showAppMessage(
            context,
            AppLocalizations.of(context)!.timeSavedMessage(
              _courseNameWithoutParentheses(widget.course.name),
            ),
          );
        }
      }

      
      if (state.stopwatchRunning[widget.course.id] ?? false) {
        final e = state.currentElapsedStopwatch(widget.course.id).inSeconds;
        if (e >= _kMaxSecs) {
          await state.stopStopwatch(widget.course.id);
          if (!mounted) return;
          showAppMessage(
            context,
            AppLocalizations.of(context)!.timeSavedMessage(
              _courseNameWithoutParentheses(widget.course.name),
            ),
          );
        }
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _kbCtrl.dispose();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    _hNode.removeListener(_handleFocusChange);
    _mNode.removeListener(_handleFocusChange);
    _sNode.removeListener(_handleFocusChange);
    _hNode.dispose();
    _mNode.dispose();
    _sNode.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    _updateCondensedMode();
  }

  void _updateCondensedMode() {
    final bool timerFocused = _hNode.hasFocus || _mNode.hasFocus || _sNode.hasFocus;
    final bool shouldBeCondensed = _kbOpen && timerFocused;

    if (shouldBeCondensed) {
      _kbCtrl.forward();
      // Only force-switch to Timer tab if not already there
      if (_tabs.index != 0) {
        _tabs.animateTo(0);
      }
    } else {
      _kbCtrl.reverse();
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() {
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    final bottomPx = view?.viewInsets.bottom ?? 0.0;
    final dpr = view?.devicePixelRatio ??
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final bottom = bottomPx / dpr;

    final nowOpen = bottom > 0;
    if (nowOpen == _kbOpen) return;
    _kbOpen = nowOpen;
    _updateCondensedMode();
  }

  String _fmt(int s) => _fmtHMS(s);

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    showAppMessage(context, msg, isError: isError);
  }

  void _handleTabChange() {
    if (!mounted || _restoringTab) {
      setState(() {});
      return;
    }
    if (!_tabs.indexIsChanging) {
      final newIndex = _tabs.index;
      if (_shouldConfirmPomodoroSwitch(newIndex)) {
        _restoringTab = true;
        Future.microtask(() async {
          final ok = await _confirmLeavePomodoro();
          if (!mounted) return;
          if (ok) {
            final state = context.read<AppState>();
            await state.resetPomodoroAndSave(widget.course.id);
            await state.waitForPendingReflections();
            if (!mounted) return;
            _lastSettledTab = newIndex;
          } else {
            _tabs.animateTo(2);
            _lastSettledTab = 2;
          }
          _restoringTab = false;
          if (mounted) setState(() {});
        });
        return;
      }
      _lastSettledTab = newIndex;
    }
    setState(() {});
  }

  bool _shouldConfirmPomodoroSwitch(int newIndex) {
    if (_lastSettledTab != 2 || newIndex == 2) return false;
    final state = context.read<AppState>();
    final running = state.pomodoroRunning[widget.course.id] ?? false;
    final paused = state.pomodoroPaused[widget.course.id] ?? false;
    return running || paused;
  }

  Future<bool> _confirmLeavePomodoro() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leavePomodoroTitle),
        content: Text(AppLocalizations.of(context)!.leavePomodoroMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.stay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.resetAndLeave),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _handleWillPop() async {
    final state = context.read<AppState>();
    final running = state.pomodoroRunning[widget.course.id] ?? false;
    final paused = state.pomodoroPaused[widget.course.id] ?? false;
    if (!running && !paused) return true;
    final ok = await _confirmLeavePomodoro();
    if (ok) {
      await state.resetPomodoroAndSave(widget.course.id);
      await state.waitForPendingReflections();
    }
    return ok;
  }

  
  Future<void> _startTimer() async {
    final state = context.read<AppState>();

    
    if (_hasAnyActive(state)) {
      final info = _activeInfo(state);
      final otherId = info?.id;
      final kind = info?.kind ?? 'session';
      if (otherId != null) {
        state.courses.firstWhere(
          (c) => c.id == otherId,
          orElse: () => Course(
            id: otherId,
            name: 'Course',
            day: '',
            start: '',
            end: '',
            colorValue: 0,
          ),
        );
      }
      final l10n = AppLocalizations.of(context)!;
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }

    final h = int.tryParse(_hCtrl.text) ?? 0;
    final m = int.tryParse(_mCtrl.text) ?? 0;
    final s = int.tryParse(_sCtrl.text) ?? 0;

    int total = h * 3600 + m * 60 + s;
    if (total <= 0) {
      // Close the input/pop-up (if any) then show an error message
      if (Navigator.canPop(context)) Navigator.pop(context);
      _snack(AppLocalizations.of(context)!.enterTimeFirst, isError: true);
      return;
    }
    if (total > _kMaxSecs) {
      total = _kMaxSecs;
      _snack(AppLocalizations.of(context)!.maxTimeCapped, isError: true);
    }

    await _savePlannedSecs(total);
    state.startTimer(widget.course.id);
    setState(() {});
  }

  Future<void> _doneTimer() async {
    final state = context.read<AppState>();

    
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final planned = await _loadPlannedSecs();
    final seconds = await state.stopTimer(widget.course.id);
    if (planned != null) {
      await _clearPlannedSecs();
    }

    if (!navigator.mounted) return;
    if (seconds <= 0 || !state.courseSheetOpen) {
      navigator.pop();
    }
    
    showAppMessage(
      navigator.context,
      l10n.timeSavedMessage(_courseNameWithoutParentheses(widget.course.name)),
    );
  }

  
  Future<void> _startStopwatch() async {
    final state = context.read<AppState>();

    if (_hasAnyActive(state)) {
      final info = _activeInfo(state);
      final otherId = info?.id;
      final kind = info?.kind ?? 'session';
      if (otherId != null) {
        state.courses.firstWhere(
          (c) => c.id == otherId,
          orElse: () => Course(
            id: otherId,
            name: 'Course',
            day: '',
            start: '',
            end: '',
            colorValue: 0,
          ),
        );
      }
      final l10n = AppLocalizations.of(context)!;
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }

    state.startStopwatch(widget.course.id);
    setState(() {});
  }

  Future<void> _doneStopwatch() async {
    final state = context.read<AppState>();

    
    if (!(state.stopwatchRunning[widget.course.id] ?? false) &&
        state.currentElapsedStopwatch(widget.course.id).inSeconds == 0) {
      _snack(AppLocalizations.of(context)!.nothingToSave, isError: true);
      return;
    }

    
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final seconds = await state.stopStopwatch(widget.course.id);

    if (!navigator.mounted) return;
    if (seconds <= 0 || !state.courseSheetOpen) {
      navigator.pop();
    }
    
    showAppMessage(
      navigator.context,
      l10n.timeSavedMessage(_courseNameWithoutParentheses(widget.course.name)),
    );
  }

  Future<void> _startPomodoro() async {
    final state = context.read<AppState>();
    final begun = state.startPomodoro(widget.course.id);
    if (!begun) {
      final l10n = AppLocalizations.of(context)!;
      final info = _activeInfo(state);
      final kind = info?.kind ?? 'session';
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  Future<void> _pausePomodoro() async {
    final state = context.read<AppState>();
    await state.pausePomodoro(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _resumePomodoro() async {
    final state = context.read<AppState>();
    await state.resumePomodoro(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _skipPomodoroBreak() async {
    final state = context.read<AppState>();
    await state.skipPomodoroBreak(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _resetPomodoroCycle() async {
    final state = context.read<AppState>();
    
    await state.resetPomodoroAndSave(widget.course.id);
    if (mounted) setState(() {});
  }

  

  
  void _openEditCourseDialog(BuildContext context) {
    final state = context.read<AppState>();

    
    final course = state.courses.firstWhere(
      (c) => c.id == widget.course.id,
      orElse: () => widget.course,
    );

    final nameCtrl = TextEditingController(text: course.name);
    Color selected = course.color;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool showCustomPicker = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.editCourse),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(32),
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\p{L}\p{N} ]', unicode: true),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.courseName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(AppLocalizations.of(context)!.color,
                            style: Theme.of(ctx).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final c in _colorChoices.take(9))
                            GestureDetector(
                              onTap: () => setLocal(() {
                                selected = c;
                                showCustomPicker = false;
                              }),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: selected.toARGB32() == c.toARGB32()
                                      ? Border.all(width: 3, color: Colors.black54)
                                      : null,
                                ),
                              ),
                            ),
                          ColorPickerButton(
                            color: selected,
                            onCustomTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setLocal(() => showCustomPicker = !showCustomPicker);
                            },
                            onColorPicked: (color) =>
                                setLocal(() => selected = color),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: showCustomPicker
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: 16),
                            CustomColorPicker(
                              initial: selected,
                              onChanged: (c) => setLocal(() => selected = c),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) return;

                    final updated = course.copyWith(
                      name: newName,
                      colorValue: selected.toARGB32(),
                    );

                    
                    final navigator = Navigator.of(ctx);
                    final appState = ctx.read<AppState>();

                    await appState.updateCourse(updated);

                    
                    if (!mounted) {
                      return; 
                    }
                    navigator.pop(); 
                    setState(() {}); 
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  

  Widget _buildTimerTab() {
    final state = context.watch<AppState>();

    return FutureBuilder<int?>(
      future: _loadPlannedSecs(),
      builder: (context, snap) {
        final planned = (snap.data ?? 0).clamp(0, _kMaxSecs);
        final runningForThisCourse =
            state.timerRunning[widget.course.id] ?? false;

        final elapsed = runningForThisCourse
            ? state.currentElapsedTimer(widget.course.id).inSeconds
            : 0;
        final remaining = runningForThisCourse
            ? (planned - elapsed).clamp(0, _kMaxSecs)
            : _readInputsCapped();

        return LayoutBuilder(
          builder: (context, c) {
            final kb = MediaQuery.of(context).viewInsets.bottom;
            final h = c.maxHeight;
            final usable = kb > 0 ? h - kb : h;

            double ay(double yPx) => ((yPx / h) * 2 - 1).clamp(-1.0, 1.0);

            final timerFocused = _hNode.hasFocus || _mNode.hasFocus || _sNode.hasFocus;
            final bool isCondensed = _kbOpen && timerFocused;
            const double gapPx = 100;
            const double hintGapPx = 84;

            final inputsY = isCondensed ? usable / 2 : h / 2;
            final timerY = inputsY + gapPx;
            final hintY = inputsY - hintGapPx;

            const dur = Duration(milliseconds: 220);
            const curve = Curves.easeOutCubic;

            final inputsEnabled = !runningForThisCourse;

            return SizedBox(
              width: double.infinity,
              height: h,
              child: Stack(
                children: [
                  
                  AnimatedAlign(
                    alignment: Alignment(0, ay(hintY)),
                    duration: dur,
                    curve: curve,
                    child: SizeTransition(
                      sizeFactor: ReverseAnimation(_fadeAway),
                      axisAlignment: -1.0,
                      child: FadeTransition(
                        opacity: ReverseAnimation(_fadeAway),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.typeTimeToStudy,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              SizedBox(height: 6),
                              Icon(Icons.arrow_downward,
                                  size: 18, color: Colors.grey),
                              SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  
                  AnimatedAlign(
                    alignment: Alignment(0, ay(inputsY)),
                    duration: dur,
                    curve: curve,
                    child: SlideTransition(
                      position: _kbOpen
                          ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
                          : _inputSlide,
                      child: _timeInputsRow(enabled: inputsEnabled),
                    ),
                  ),

                  
                  AnimatedAlign(
                    alignment: Alignment(0, ay(timerY)),
                    duration: dur,
                    curve: curve,
                    child: FadeTransition(
                      opacity: ReverseAnimation(_fadeAway),
                      child: SlideTransition(
                        position: _timerSlide,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                _fmt(remaining),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                AppLocalizations.of(context)!.maxTime,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStopwatchTab() {
    final state = context.watch<AppState>();
    final elapsed = state
        .currentElapsedStopwatch(widget.course.id)
        .inSeconds
        .clamp(0, _kMaxSecs);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmt(elapsed),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.maxTime, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPomodoroTab() {
    final state = context.watch<AppState>();
    final phase = state.pomodoroPhase[widget.course.id] ?? PomodoroPhase.work;
    final remaining =
        state.currentPomodoroRemaining(widget.course.id).inSeconds;
    final elapsed = state.currentPomodoroElapsed(widget.course.id).inSeconds;
    final total =
        state.pomodoroPhaseDurationFor(widget.course.id).inSeconds;
    final completed = state.pomodoroCompletedWorkFor(widget.course.id);
    final isPaused = state.pomodoroPaused[widget.course.id] ?? false;
    final sliderValue = _pendingLongBreak ??
        state.pomodoroLongBreakMinutesFor(widget.course.id).toDouble();
    final minLong = AppState.pomodoroLongBreakMinMinutes.toDouble();
    final maxLong = AppState.pomodoroLongBreakMaxMinutes.toDouble();

    final hasStarted = (state.pomodoroRunning[widget.course.id] ?? false) ||
        (state.pomodoroPaused[widget.course.id] ?? false) ||
        elapsed > 0;
    final sliderEnabled = !hasStarted;
    final phaseLabel = hasStarted 
        ? _pomodoroPhaseLabel(phase) 
        : AppLocalizations.of(context)!.start;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const Spacer(),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '$phaseLabel${isPaused ? ' (${AppLocalizations.of(context)!.paused})' : ''}',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _fmt(remaining),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_fmt(elapsed)} / ${_fmt(total)} ${AppLocalizations.of(context)!.elapsed}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.completedPomodoros(completed),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppLocalizations.of(context)!.longBreakLength(sliderValue.round()),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: sliderValue,
                      min: minLong,
                      max: maxLong,
                      divisions: (maxLong - minLong).round(),
                      label: '${sliderValue.round()} ${AppLocalizations.of(context)!.minutes_plural}',
                      onChanged: sliderEnabled
                          ? (value) => setState(() => _pendingLongBreak = value)
                          : null,
                      onChangeEnd: sliderEnabled
                          ? (value) async {
                              final appState = context.read<AppState>();
                              await appState.setPomodoroLongBreakMinutes(
                                  widget.course.id, value.round());
                              if (!mounted) return;
                              setState(() => _pendingLongBreak = null);
                            }
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPomodoroControls() {
    final state = context.watch<AppState>();
    final hasSession = state.pomodoroRunning[widget.course.id] ?? false;
    final isPaused = state.pomodoroPaused[widget.course.id] ?? false;
    final onBreak = state.pomodoroIsOnBreak(widget.course.id);
    final elapsed =
        state.currentPomodoroElapsed(widget.course.id).inSeconds;
    final canReset = hasSession || elapsed > 0;
  

    IconData primaryIcon;
    String primaryLabel;
    VoidCallback? primaryAction;

    if (!hasSession) {
      primaryIcon = Icons.play_arrow;
      primaryLabel = AppLocalizations.of(context)!.start;
      primaryAction = () => _startPomodoro();
    } else if (isPaused) {
      primaryIcon = Icons.play_arrow;
      primaryLabel = AppLocalizations.of(context)!.resume;
      primaryAction = () => _resumePomodoro();
    } else {
      primaryIcon = Icons.pause;
      primaryLabel = AppLocalizations.of(context)!.pause;
      primaryAction = () => _pausePomodoro();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: primaryAction,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canReset ? _resetPomodoroCycle : null,
                icon: const Icon(Icons.stop),
                label: Text(AppLocalizations.of(context)!.reset),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onBreak ? _skipPomodoroBreak : null,
            icon: const Icon(Icons.skip_next),
            label: Text(AppLocalizations.of(context)!.skipBreak),
          ),
        ),
        const SizedBox(height: 8),
        
      ],
    );
  }

  String _pomodoroPhaseLabel(PomodoroPhase phase) {
    final l10n = AppLocalizations.of(context)!;
    switch (phase) {
      case PomodoroPhase.work:
        return l10n.work;
      case PomodoroPhase.shortBreak:
        return l10n.shortBreak;
      case PomodoroPhase.longBreak:
        return l10n.longBreak;
    }
  }

  

  Widget _timeInputsRow({required bool enabled}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _numField(
          _hCtrl,
          _hNode,
          AppLocalizations.of(context)!.hUnit,
          enabled: enabled,
          maxLen: 2,
          nextNode: _mNode,
          nextCtrl: _mCtrl,
        ),
        const SizedBox(width: 12),
        _numField(
          _mCtrl,
          _mNode,
          AppLocalizations.of(context)!.mUnit,
          enabled: enabled,
          maxLen: 2,
          prevNode: _hNode,
          prevCtrl: _hCtrl,
          nextNode: _sNode,
          nextCtrl: _sCtrl,
        ),
        const SizedBox(width: 12),
        _numField(
          _sCtrl,
          _sNode,
          AppLocalizations.of(context)!.sUnit,
          enabled: enabled,
          maxLen: 2,
          prevNode: _mNode,
          prevCtrl: _mCtrl,
        ),
      ],
    );
  }

  int _readInputsCapped() {
    final h = int.tryParse(_hCtrl.text) ?? 0;
    final m = int.tryParse(_mCtrl.text) ?? 0;
    final s = int.tryParse(_sCtrl.text) ?? 0;
    int total = h * 3600 + m * 60 + s;
    if (total > _kMaxSecs) total = _kMaxSecs;
    if (total < 0) total = 0;
    return total;
  }

  void _focusNumericField(FocusNode node, TextEditingController ctrl) {
    if (!mounted) return;
    final scope = FocusScope.of(context);
    final current = scope.focusedChild;
    if (current != null && current != node) {
      current.unfocus(disposition: UnfocusDisposition.scope);
    }
    scope.requestFocus(node);
    final offset = ctrl.text.length;
    // Keep cursor in the tapped field and at the end of current value.
    Future.microtask(() {
      if (!mounted) return;
      if (!node.hasFocus) {
        FocusScope.of(context).requestFocus(node);
      }
      ctrl.selection = TextSelection.collapsed(offset: offset);
    });
  }

  Widget _numField(
    TextEditingController ctrl,
    FocusNode node,
    String label, {
    required bool enabled,
    required int maxLen,
    FocusNode? prevNode,
    TextEditingController? prevCtrl,
    FocusNode? nextNode,
    TextEditingController? nextCtrl,
  }) {
    return SizedBox(
      width: 84,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _focusNumericField(node, ctrl) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: TextField(
                key: ValueKey(label),
                controller: ctrl,
                focusNode: node,
                enabled: enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onTap: enabled ? () => _focusNumericField(node, ctrl) : null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(maxLen),
                ],
                onChanged: (value) {
                  setState(() {});
                  if (!enabled || !node.hasFocus) return;
                  if (value.isEmpty &&
                      prevNode != null &&
                      prevCtrl != null &&
                      prevCtrl.text.isNotEmpty) {
                    _focusNumericField(prevNode, prevCtrl);
                    return;
                  }
                  if (value.length < maxLen) return;
                  if (nextNode != null && nextCtrl != null) {
                    _focusNumericField(nextNode, nextCtrl);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    final live = state.courses.firstWhere(
      (c) => c.id == widget.course.id,
      orElse: () => widget.course,
    );

    final isTimerRunningForThis = state.timerRunning[widget.course.id] ?? false;
    final isStopwatchRunningForThis =
        state.stopwatchRunning[widget.course.id] ?? false;
    final isPomodoroActiveForThis =
        (state.pomodoroRunning[widget.course.id] ?? false) ||
            (state.pomodoroPaused[widget.course.id] ?? false);
    
    final isAnyRunningCombined = isTimerRunningForThis || 
        isStopwatchRunningForThis || 
        isPomodoroActiveForThis;

    final timerFocused = _hNode.hasFocus || _mNode.hasFocus || _sNode.hasFocus;
    final bool isCondensed = _kbOpen && timerFocused;

    final shouldGuardPop = isPomodoroActiveForThis;

    return PopScope(
      canPop: !shouldGuardPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final allow = await _handleWillPop();
        if (allow && mounted) {
          navigator.pop(result);
        }
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 5,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 10),

            ListTile(
              leading: CircleAvatar(backgroundColor: live.color),
              title: Text(live.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                IconButton(
                  tooltip: live.hiddenFromLeaderboard
                      ? AppLocalizations.of(context)!.unhideFromLeaderboard
                      : AppLocalizations.of(context)!.hideFromLeaderboard,
                  icon: Icon(
                    live.hiddenFromLeaderboard
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: isAnyRunningCombined ? Colors.grey : Colors.blueGrey,
                  ),
                  onPressed: isAnyRunningCombined
                      ? null
                      : () async {
                          final appState = context.read<AppState>();
                          final updated = live.copyWith(
                              hiddenFromLeaderboard:
                                  !live.hiddenFromLeaderboard);
                          await appState.updateCourse(updated);
                          setState(() {}); // Toggle icon state immediately
                          
                          if (!mounted || !context.mounted) return;
                          
                          // Brief delay so the user sees the icon change before the popup closes
                          await Future.delayed(const Duration(milliseconds: 300));
                          if (!mounted || !context.mounted) return;
                          
                          Navigator.pop(context);

                          final msg = updated.hiddenFromLeaderboard
                              ? AppLocalizations.of(context)!.courseHiddenFromLeaderboard
                              : AppLocalizations.of(context)!.courseVisibleInLeaderboard;
                          showAppMessage(context, msg);
                        },
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.edit,
                  icon: Icon(Icons.edit, 
                    color: isAnyRunningCombined ? Colors.grey : Colors.blueGrey
                  ),
                  onPressed: isAnyRunningCombined ? null : () => _openEditCourseDialog(context),
                ),
                  IconButton(
                    icon: Icon(Icons.delete, 
                      color: isAnyRunningCombined ? Colors.grey : Colors.red
                    ),
                    tooltip: 'Delete Course',
                    onPressed: isAnyRunningCombined ? null : () async {
                      
                      final appState = context.read<AppState>();
                      final navigator = Navigator.of(context);

                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.deleteCourseTitle),
                          content: Text(AppLocalizations.of(context)!.deleteCourseMessage),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              icon: const Icon(Icons.delete),
                              label: Text(AppLocalizations.of(context)!.delete),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        await appState.removeCourse(widget.course.id);
                        
                        navigator.pop(); 
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            
            SizedBox(
              height: kTextTabBarHeight,
              width: double.infinity,
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                firstCurve: Curves.easeInOut,
                secondCurve: Curves.easeInOut,
                crossFadeState: isCondensed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Center(
                  child: TextButton(
                    onPressed: () => _tabs.animateTo(0),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.timerTab,
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                secondChild: Align(
                  alignment: Alignment.center,
                  child: TabBar(
                    controller: _tabs,
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.timerTab),
                      Tab(text: AppLocalizations.of(context)!.stopwatchTab),
                      Tab(text: AppLocalizations.of(context)!.pomodoroTab),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: IgnorePointer(
                // Keep timer inputs interactive while keyboard is open so
                // users can switch H/M/S focus directly.
                ignoring: _kbOpen && _tabs.index != 0,
                child: TabBarView(
                  controller: _tabs,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTimerTab(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isCondensed
                          ? const SizedBox.shrink()
                          : _buildStopwatchTab(),
                    ),
                    _buildPomodoroTab(),
                  ],
                ),
              ),
            ),

            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _tabs.index == 2
                  ? _buildPomodoroControls()
                  : FadeTransition(
                      opacity: ReverseAnimation(_fadeAway),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _tabs.index == 0
                                  ? (isTimerRunningForThis || isPomodoroActiveForThis
                                      ? null
                                      : _startTimer)
                                  : (isStopwatchRunningForThis || isPomodoroActiveForThis
                                      ? null
                                      : _startStopwatch),
                              icon: const Icon(Icons.play_arrow),
                              label: Text(AppLocalizations.of(context)!.start),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _tabs.index == 0
                                  ? (isTimerRunningForThis
                                      ? _doneTimer
                                      : null)
                                  : (isStopwatchRunningForThis
                                      ? _doneStopwatch
                                      : null),
                              icon: const Icon(Icons.check),
                              label: Text(AppLocalizations.of(context)!.done),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StreakTitle extends StatelessWidget {
  const _StreakTitle();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = state.streakCount;
    final hasToday = state.hasStudyToday;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (count == 0) {
      return Text(
        l10n.noStreakYet,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withAlpha((0.8 * 255).round()),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: 22,
          color: hasToday ? Colors.orangeAccent : Colors.grey.shade400,
        ),
        const SizedBox(width: 6),
        Text(
          l10n.streakDays(count),
          style: theme.textTheme.titleMedium?.copyWith(
            color: hasToday ? state.accentColor : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
