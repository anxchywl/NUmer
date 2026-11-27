import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'settings_heading.dart';

class SettingsDisplaySection extends StatelessWidget {
  const SettingsDisplaySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeading(l10n.displayTotalStudyTime),
        const SizedBox(height: 12),
        const _HomeSummarySwipeSelector(),
        const SizedBox(height: 24),
        SettingsHeading(l10n.displayProgressBar),
        const SizedBox(height: 12),
        const _ProgressViewSelector(),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.justSwipeIt,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSummarySwipeSelector extends StatefulWidget {
  const _HomeSummarySwipeSelector();

  @override
  State<_HomeSummarySwipeSelector> createState() =>
      _HomeSummarySwipeSelectorState();
}

class _HomeSummarySwipeSelectorState extends State<_HomeSummarySwipeSelector>
    with SingleTickerProviderStateMixin {
  final List<HomeSummaryRange> _ranges = [
    HomeSummaryRange.off,
    HomeSummaryRange.today,
    HomeSummaryRange.week,
    HomeSummaryRange.month,
    HomeSummaryRange.year,
    HomeSummaryRange.allTime,
  ];
  int _index = 0;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    final newIndex = _ranges.indexOf(state.homeSummaryRange);
    if (newIndex != _index && newIndex >= 0) {
      _index = newIndex;
    }
  }

  Future<void> _changeRange(BuildContext context, int dir) async {
    final state = context.read<AppState>();
    final newIndex = (_index + dir).clamp(0, _ranges.length - 1);
    if (newIndex == _index) return;

    HapticFeedback.selectionClick();
    setState(() => _slideDir = dir.toDouble());
    await _anim.forward(from: 0);
    if (!mounted) return;
    setState(() => _index = newIndex);
    await state.setHomeSummaryRange(_ranges[_index]);
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_ranges[_index]) {
      HomeSummaryRange.off => AppLocalizations.of(context)!.off,
      HomeSummaryRange.today => AppLocalizations.of(context)!.currentDay,
      HomeSummaryRange.week => AppLocalizations.of(context)!.thisWeekShort,
      HomeSummaryRange.month => AppLocalizations.of(context)!.thisMonthShort,
      HomeSummaryRange.year => AppLocalizations.of(context)!.thisYearShort,
      HomeSummaryRange.allTime => AppLocalizations.of(context)!.overall,
    };

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 100) _changeRange(context, -1);
            if (velocity < -100) _changeRange(context, 1);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withAlpha((0.4 * 255).round()),
            ),
            child: SlideTransition(
              position: _slide.drive(
                Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(0.15 * -_slideDir, 0),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

class _ProgressViewSelector extends StatefulWidget {
  const _ProgressViewSelector();

  @override
  State<_ProgressViewSelector> createState() => _ProgressViewSelectorState();
}

class _ProgressViewSelectorState extends State<_ProgressViewSelector>
    with SingleTickerProviderStateMixin {
  final List<ProgressView> _views = [
    ProgressView.off,
    ProgressView.day,
    ProgressView.week,
  ];
  int _index = 0;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    final newIndex = _views.indexOf(state.progressView);
    if (newIndex != _index && newIndex >= 0) {
      _index = newIndex;
    }
  }

  Future<void> _changeView(int dir) async {
    final newIndex = (_index + dir).clamp(0, _views.length - 1);
    if (newIndex == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _slideDir = dir.toDouble());
    await _anim.forward(from: 0);
    if (!mounted) return;
    setState(() => _index = newIndex);
    await context.read<AppState>().setProgressView(_views[_index]);
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_views[_index]) {
      ProgressView.day => AppLocalizations.of(context)!.dayGoalLabel,
      ProgressView.week => AppLocalizations.of(context)!.weekGoalLabel,
      ProgressView.off => AppLocalizations.of(context)!.off,
    };
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 100) _changeView(-1);
            if (velocity < -100) _changeView(1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withAlpha((0.4 * 255).round()),
            ),
            child: SlideTransition(
              position: _slide.drive(
                Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(0.15 * -_slideDir, 0),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
