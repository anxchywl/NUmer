import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/ai_analysis/ai_analysis.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'streak_title.dart';
import 'sync_status_chip.dart';

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
          if (notification.direction == ScrollDirection.reverse &&
              _fabVisible) {
            setState(() => _fabVisible = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_fabVisible) {
            setState(() => _fabVisible = true);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            _appBar(),
            const SliverToBoxAdapter(
              child: Column(
                children: [
                  FirstRunCreditsGate(),
                  AutoFinishWatcher(),
                  ActiveSessionBar(),
                ],
              ),
            ),
            if (courses.isEmpty)
              _emptyState(context)
            else
              CourseListSliver(
                onOpenCourse: (c) => showCourseTimeSheet(context, c),
              ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: _isIos(context)
                    ? _iosBottomNavClearance(context)
                    : MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: courses.isEmpty
          ? null
          : _isIos(context)
          ? _iosFab(context)
          : _materialFab(context),
    );
  }

  Widget _appBar() {
    return SliverAppBar(
      title: const StreakTitle(),
      centerTitle: false, // Ensure title is left-aligned on iOS
      actions: [
        const Center(
          child: Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: SyncStatusChip(),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: _isIos(context)
            ? _IosLiquidActionPill(
                icon: Icons.add,
                label: AppLocalizations.of(context)!.addCourse,
                onPressed: () => showAddCourseSheet(context),
              )
            : FilledButton.icon(
                onPressed: () => showAddCourseSheet(context),
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.addCourse),
              ),
      ),
    );
  }

  Widget _fabMotion({required Widget child}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
      offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutQuart,
        opacity: _fabVisible ? 1 : 0,
        child: IgnorePointer(ignoring: !_fabVisible, child: child),
      ),
    );
  }

  Widget _iosFab(BuildContext context) {
    return _fabMotion(
      child: Padding(
        padding: EdgeInsets.only(bottom: _iosFabBottomLift(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _aiPill(context),
            const SizedBox(height: 10),
            _IosLiquidActionPill(
              icon: Icons.add,
              label: AppLocalizations.of(context)!.addCourse,
              onPressed: () => showAddCourseSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiPill(BuildContext context) {
    return _IosLiquidActionPill(
      icon: Icons.auto_awesome_outlined,
      iconOnly: true,
      iconSize: 24,
      iconPadding: const EdgeInsets.all(13),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AiAnalysisScreen()));
      },
    );
  }

  Widget _materialFab(BuildContext context) {
    return _fabMotion(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'ai-fab',
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 4,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiAnalysisScreen()),
              );
            },
            child: const Icon(Icons.auto_awesome_outlined),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add-fab',
            onPressed: () => showAddCourseSheet(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
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
