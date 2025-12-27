import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/profile_form.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/export_session_dialog.dart';

class AccountScreen extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const AccountScreen({super.key, this.onThemeChange});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _confirmDeleteAccount() async {
    
    final auth = context.read<AuthController>();
    final appState = context.read<AppState>();
    final syncService = context.read<SyncService>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final currentContext = context;

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return AlertDialog(
          icon: Icon(
            Icons.warning_rounded,
            color: scheme.error,
            size: 32,
          ),
          title: Text(l10n.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteAccountSubtitle),
              const SizedBox(height: 6),
              Text(l10n.deleteAccountHoldConfirmDetail),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            SizedBox(
              width: 110,
              child: _HoldToConfirmButton(
                label: l10n.delete,
                holdDuration: const Duration(seconds: 5),
                backgroundColor: scheme.errorContainer,
                fillColor: scheme.error,
                textColor: scheme.error,
                onConfirmed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    
    await appState.stopAndSaveAllActiveSessions();
    await appState.waitForPendingReflections();
    await syncService.syncNow();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(AppLocalizations.of(context)!.deletingAccount),
          ],
        ),
      ),
    );

    
    String? error;
    try {
      error = await auth.deleteAccount();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (error != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.themeMode;
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    
    
    if (user == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(AppLocalizations.of(context)!.settingsTitle),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child:
                    Text(AppLocalizations.of(context)!.pleaseSignInToViewAccount),
              ),
            ),
          ],
        ),
      );
    }

    final profile = auth.profile;
    final displayName = (state.profileName != null && state.profileName!.trim().isNotEmpty)
      ? state.profileName!.trim()
      : (((profile?['displayName'] as String?) ?? user.displayName ?? 'Unknown user')
        .trim());
    final loginLabel =
      (profile?['login'] as String?) ?? user.email ?? 'Unknown login';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(AppLocalizations.of(context)!.settingsTitle)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(AppLocalizations.of(context)!.account,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          title: Text(displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loginLabel),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex:
                                  Localizations.localeOf(context).languageCode ==
                                          'ru'
                                      ? 2
                                      : 1,
                              child: TextButton.icon(
                                onPressed: auth.isBusy
                                    ? null
                                    : () async {
                                        final authController =
                                            context.read<AuthController>();
                                        final appState = context.read<AppState>();
                                        final syncService = context.read<SyncService>();
                                        final navigator = Navigator.of(context);
                                        
                                        await appState.stopAndSaveAllActiveSessions();
                                        await appState.waitForPendingReflections();
                                        await syncService.syncNow();
                                        
                                        await authController.signOut();
                                        if (!mounted) return;
                                        appState.reset();
                                        navigator.pushReplacementNamed('/auth');
                                      },
                                icon: const Icon(Icons.logout),
                                label: Text(AppLocalizations.of(context)!.signOut),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex:
                                  Localizations.localeOf(context).languageCode ==
                                          'ru'
                                      ? 3
                                      : 1,
                              child: FilledButton.icon(
                                onPressed: context.watch<SyncService>().status ==
                                        SyncStatus.syncing
                                    ? null
                                    : () => context
                                        .read<SyncService>()
                                        .syncNow(full: true),
                                icon: context.watch<SyncService>().status ==
                                        SyncStatus.syncing
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child:
                                      Text(AppLocalizations.of(context)!.syncNow),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(AppLocalizations.of(context)!.profile,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                auth.isProfileReady && state.isLoaded
                    ? Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ProfileForm(
                            initialName: state.profileName ?? '',
                            initialMajor: state.major,
                            initialContact: state.profileContact,
                            initialGoal: state.profileGoal,
                            initialAvatarIndex: state.profileAvatarIndex,
                            initialAvatarColorValue:
                                state.profileAvatarColorValue,
                            initialAvatarBytes: state.profileAvatarImage,
                            primaryButtonLabel:
                                AppLocalizations.of(context)!.save,
                            onSubmit: (data) async {
                              final appState = context.read<AppState>();
                              await appState.saveProfile(
                                name: data.name,
                                goal: data.goal,
                                majorText: data.major,
                                contact: data.contact,
                                avatarIndex: data.avatarIndex,
                                avatarColorValue: data.avatarColorValue,
                                avatarBytes: data.avatarBytes,
                              );
                            },
                          ),
                        ),
                      )
                    : const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                const SizedBox(height: 32),
          
          Text(AppLocalizations.of(context)!.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(AppLocalizations.of(context)!.light)),
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(AppLocalizations.of(context)!.system),
                  )),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(AppLocalizations.of(context)!.dark)),
            ],
            selected: {mode},
            onSelectionChanged: (s) async {
              final mode = s.first;
              final appState = context.read<AppState>();
              await widget.onThemeChange?.call(mode);
              if (!mounted) return;
              appState.setThemeMode(mode);
            },
          ),
          const SizedBox(height: 32),
          
          Text(AppLocalizations.of(context)!.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'ru',
                  label: Text(AppLocalizations.of(context)!.russian)),
              ButtonSegment(
                  value: 'en',
                  label: Text(AppLocalizations.of(context)!.english)),
              ButtonSegment(
                  value: 'kk',
                  label: Text(AppLocalizations.of(context)!.kazakh)),
            ],
            selected: {Localizations.localeOf(context).languageCode},
            onSelectionChanged: (Set<String> newSelection) async {
              final newLocale = newSelection.first;
              if (newLocale == Localizations.localeOf(context).languageCode) return;
              
              final appState = context.read<AppState>();
              await appState.setLocale(Locale(newLocale));
            },
          ),
          const SizedBox(height: 32),


          
          Text(AppLocalizations.of(context)!.weekStartsOn,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<WeekStart>(
            segments: [
              ButtonSegment(value: WeekStart.monday, label: Text(AppLocalizations.of(context)!.mon)),
              ButtonSegment(value: WeekStart.sunday, label: Text(AppLocalizations.of(context)!.sun)),
            ],
            selected: {state.weekStart},
            onSelectionChanged: (s) =>
                context.read<AppState>().setWeekStart(s.first),
          ),
          const SizedBox(height: 24),

          Divider(color: Colors.grey.shade300, thickness: 1),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.displayTotalStudyTime,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _HomeSummarySwipeSelector(),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.displayProgressBar,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _ProgressViewSelector(),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.quickNotes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _QuickNotesToggle(),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.wantToReceiveNudges,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _NudgesToggle(),
          const SizedBox(height: 24),
          
          Divider(color: Colors.grey.shade300, thickness: 1),
          const SizedBox(height: 24),

          
          Text(AppLocalizations.of(context)!.data,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(AppLocalizations.of(context)!.exportToCalendar),
              subtitle: Text(AppLocalizations.of(context)!.exportToCalendarSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const ExportSessionSheet(),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Divider(color: Colors.grey.shade300, thickness: 1),

          
          ListTile(
            leading: Icon(Icons.delete_forever, 
              color: Theme.of(context).colorScheme.error
            ),
            title: Text(AppLocalizations.of(context)!.deleteAccount, 
              style: TextStyle(
                color: Theme.of(context).colorScheme.error
              )
            ),
            subtitle: Text(AppLocalizations.of(context)!.deleteAccountSubtitle),
            enabled: !auth.isBusy,
            onTap: auth.isBusy ? null : _confirmDeleteAccount,
          ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldToConfirmButton extends StatefulWidget {
  const _HoldToConfirmButton({
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(seconds: 5),
    this.backgroundColor,
    this.fillColor,
    this.textColor,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final Color? backgroundColor;
  final Color? fillColor;
  final Color? textColor;

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_confirmed) {
        _confirmed = true;
        HapticFeedback.mediumImpact();
        widget.onConfirmed();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDuration != widget.holdDuration) {
      _controller.duration = widget.holdDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_confirmed) return;
    _controller.forward(from: _controller.value);
  }

  void _cancelHold() {
    if (_confirmed) return;
    _controller.animateBack(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor = widget.backgroundColor ?? scheme.errorContainer;
    final textColor = widget.textColor ?? scheme.onError;
    final radius = BorderRadius.circular(12);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Semantics(
          button: true,
          enabled: !_confirmed,
          label: widget.label,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTapDown: _confirmed ? null : (_) => _startHold(),
              onTapUp: _confirmed ? null : (_) => _cancelHold(),
              onTapCancel: _confirmed ? null : _cancelHold,
              borderRadius: radius,
              child: SizedBox(
                height: 44,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final background =
                        Color.lerp(backgroundColor, Colors.white, _controller.value) ??
                            backgroundColor;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: radius,
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: textColor, size: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_forever),
                          const SizedBox(width: 6),
                          Text(
                            widget.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeSummarySwipeSelector extends StatefulWidget {
  @override
  State<_HomeSummarySwipeSelector> createState() =>
      _HomeSummarySwipeSelectorState();
}

class _HomeSummarySwipeSelectorState extends State<_HomeSummarySwipeSelector>
    with SingleTickerProviderStateMixin {
  final List<HomeSummaryRange> _ranges = [
    HomeSummaryRange.today,
    HomeSummaryRange.week,
    HomeSummaryRange.month,
    HomeSummaryRange.year,
    HomeSummaryRange.allTime,
  ];
  late int _index;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _index = _ranges.indexOf(state.homeSummaryRange);
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
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
                color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withAlpha((0.4 * 255).round()),
            ),
            child: SlideTransition(
              position: _slide.drive(Tween<Offset>(
                begin: Offset.zero,
                end: Offset(0.15 * -_slideDir, 0),
              )),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
  final List<ProgressView> _views = [ProgressView.day, ProgressView.week];
  late int _index;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _index = _views.indexOf(state.progressView);
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
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
    final label = _views[_index] == ProgressView.day 
      ? AppLocalizations.of(context)!.dayGoalLabel 
      : AppLocalizations.of(context)!.weekGoalLabel;
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
                color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withAlpha((0.4 * 255).round()),
            ),
            child: SlideTransition(
              position: _slide.drive(Tween<Offset>(
                begin: Offset.zero,
                end: Offset(0.15 * -_slideDir, 0),
              )),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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

class _QuickNotesToggle extends StatefulWidget {
  const _QuickNotesToggle();

  @override
  State<_QuickNotesToggle> createState() => _QuickNotesToggleState();
}

class _QuickNotesToggleState extends State<_QuickNotesToggle>
    with SingleTickerProviderStateMixin {
  late int _index;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _index = state.quickNotesEnabled ? 0 : 1;
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  Future<void> _toggle(int dir) async {
    final newIndex = (_index + dir).clamp(0, 1);
    if (newIndex == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _slideDir = dir.toDouble());
    await _anim.forward(from: 0);
    if (!mounted) return;
    setState(() => _index = newIndex);
    await context.read<AppState>().setQuickNotesEnabled(_index == 0);
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final label = _index == 0 
      ? AppLocalizations.of(context)!.on 
      : AppLocalizations.of(context)!.off;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100) _toggle(-1);
        if (velocity < -100) _toggle(1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha((0.4 * 255).round()),
        ),
        child: SlideTransition(
          position: _slide.drive(Tween<Offset>(
            begin: Offset.zero,
            end: Offset(0.15 * -_slideDir, 0),
          )),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

class _NudgesToggle extends StatefulWidget {
  const _NudgesToggle();

  @override
  State<_NudgesToggle> createState() => _NudgesToggleState();
}

class _NudgesToggleState extends State<_NudgesToggle>
    with SingleTickerProviderStateMixin {
  late int _index;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _index = state.allowNudges ? 0 : 1;
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  Future<void> _toggle(int dir) async {
    final newIndex = (_index + dir).clamp(0, 1);
    if (newIndex == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _slideDir = dir.toDouble());
    await _anim.forward(from: 0);
    if (!mounted) return;
    setState(() => _index = newIndex);
    await context.read<AppState>().setAllowNudges(_index == 0);
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final label = _index == 0 
      ? AppLocalizations.of(context)!.yes 
      : AppLocalizations.of(context)!.no;
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 100) _toggle(-1);
            if (velocity < -100) _toggle(1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withAlpha((0.4 * 255).round()),
            ),
            child: SlideTransition(
              position: _slide.drive(Tween<Offset>(
                begin: Offset.zero,
                end: Offset(0.15 * -_slideDir, 0),
              )),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context)!.justSwipeIt,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
