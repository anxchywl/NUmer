import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/account/widgets/profile_form.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/history/widgets/export_session_dialog.dart';
import 'package:numer_app/shared/widgets/universal_avatar.dart';
import 'package:numer_app/features/account/widgets/accent_color_picker.dart';

class AccountScreen extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const AccountScreen({super.key, this.onThemeChange});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isIos(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  double _iosBottomNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const navHeight = 66.0;
    const extra = 8.0;
    return navHeight + navBottomOffset + extra;
  }

  double _bottomScrollClearance(BuildContext context) {
    return _isIos(context)
        ? _iosBottomNavClearance(context)
        : MediaQuery.of(context).padding.bottom + 24;
  }

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
              Text(
                'This action is permanent and can not be undone.',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: scheme.error),
              ),
              const SizedBox(height: 8),
              const Text('Deleting your account will:'),
              const SizedBox(height: 4),
              const Text('• Remove all your study sessions'),
              const Text('• Delete your courses and habits progress'),
              const Text(
                  '• Remove you from your group and delete group you created if any'),
              const Text('• Erase your profile and settings'),
              const SizedBox(height: 12),
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
                onConfirmed: () async {
                  // After hold, show second confirmation with text input
                  final textConfirmed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => _DeleteAccountTextConfirmDialog(),
                  );
                  if (textConfirmed == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
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
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                AppLocalizations.of(context)!.settingsTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                    AppLocalizations.of(context)!.pleaseSignInToViewAccount),
              ),
            ),
          ],
        ),
      );
    }

    final profile = auth.profile;
    final displayName =
        (state.profileName != null && state.profileName!.trim().isNotEmpty)
            ? state.profileName!.trim()
            : (((profile?['displayName'] as String?) ??
                    user.displayName ??
                    'Unknown user')
                .trim());
    final loginLabel =
        (profile?['login'] as String?) ?? user.email ?? 'Unknown login';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              AppLocalizations.of(context)!.settingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                          leading: UniversalAvatar(
                            userId: user.uid,
                            name: displayName,
                            initialAvatarIndex: state.profileAvatarIndex,
                            initialAvatarColorValue:
                                state.profileAvatarColorValue,
                            alwaysShowSilhouette: true,
                            size: 48,
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
                            TextButton.icon(
                              onPressed: auth.isBusy
                                  ? null
                                  : () async {
                                      final authController =
                                          context.read<AuthController>();
                                      final appState = context.read<AppState>();
                                      final syncService =
                                          context.read<SyncService>();
                                      final navigator = Navigator.of(context);

                                      await appState
                                          .stopAndSaveAllActiveSessions();
                                      await appState
                                          .waitForPendingReflections();
                                      await syncService.syncNow();

                                      await authController.signOut();
                                      if (!mounted) return;
                                      appState.reset();
                                      navigator.pushReplacementNamed('/auth');
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                              icon: const Icon(Icons.logout, size: 18),
                              label:
                                  Text(AppLocalizations.of(context)!.signOut),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: context.watch<SyncService>().status ==
                                      SyncStatus.syncing
                                  ? null
                                  : () => context
                                      .read<SyncService>()
                                      .syncNow(full: true),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                              icon: context.watch<SyncService>().status ==
                                      SyncStatus.syncing
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  context.watch<SyncService>().status ==
                                          SyncStatus.syncing
                                      ? AppLocalizations.of(context)!.syncing
                                      : AppLocalizations.of(context)!.syncNow,
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
                Text(
                  AppLocalizations.of(context)!.profile,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                auth.isProfileReady && state.isLoaded
                    ? Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant),
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
                                uid: auth.currentUser?.uid,
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
                Text(
                  AppLocalizations.of(context)!.appearance,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    segments: [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(AppLocalizations.of(context)!.light,
                                style: const TextStyle(fontSize: 12)),
                          )),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.settings_suggest_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(AppLocalizations.of(context)!.system,
                                style: const TextStyle(fontSize: 12)),
                          )),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(AppLocalizations.of(context)!.dark,
                                style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) async {
                      final mode = s.first;
                      // onThemeChange already calls setThemeMode, so we just call it
                      await widget.onThemeChange?.call(mode);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: state.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                      ),
                    ),
                    title: Text(AppLocalizations.of(context)!.accentColor),
                    subtitle: Text(
                        AppLocalizations.of(context)!.accentColorDescription),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 16,
                            bottom:
                                16 + MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Drag Handle
                                Container(
                                  width: 32,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.accentColor,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 24),
                                AccentColorPicker(
                                  currentColor: state.accentColor,
                                  onColorChanged: (color) {
                                    state.setAccentColor(color);
                                  },
                                  onSave: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppLocalizations.of(context)!.language,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    segments: const [
                      ButtonSegment(
                          value: 'ru',
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Русский',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(fontSize: 12),
                            ),
                          )),
                      ButtonSegment(
                          value: 'en',
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'English',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(fontSize: 12),
                            ),
                          )),
                      ButtonSegment(
                          value: 'kk',
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Қазақша',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(fontSize: 12),
                            ),
                          )),
                    ],
                    selected: {Localizations.localeOf(context).languageCode},
                    onSelectionChanged: (Set<String> newSelection) async {
                      final newLocale = newSelection.first;
                      if (newLocale ==
                          Localizations.localeOf(context).languageCode) {
                        return;
                      }

                      final appState = context.read<AppState>();
                      await appState.setLocale(Locale(newLocale));
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppLocalizations.of(context)!.weekStartsOn,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<WeekStart>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    segments: [
                      ButtonSegment(
                        value: WeekStart.monday,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(AppLocalizations.of(context)!.mon,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      ButtonSegment(
                        value: WeekStart.sunday,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(AppLocalizations.of(context)!.sun,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    selected: {state.weekStart},
                    onSelectionChanged: (s) =>
                        context.read<AppState>().setWeekStart(s.first),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.displayTotalStudyTime,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _HomeSummarySwipeSelector(),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.displayProgressBar,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const _ProgressViewSelector(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.justSwipeIt,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: Icon(
                      Icons.notes_rounded,
                      color: state.quickNotesEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withAlpha(128),
                    ),
                    title: Text(AppLocalizations.of(context)!.quickNotes),
                    subtitle: Text(
                      AppLocalizations.of(context)!.quickNotesDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: state.quickNotesEnabled,
                    onChanged: (v) => state.setQuickNotesEnabled(v),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: Icon(
                      Icons.notifications_active_rounded,
                      color: state.allowNudges
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withAlpha(128),
                    ),
                    title:
                        Text(AppLocalizations.of(context)!.wantToReceiveNudges),
                    subtitle: Text(
                      AppLocalizations.of(context)!
                          .wantToReceiveNudgesDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: state.allowNudges,
                    onChanged: (v) => state.setAllowNudges(v),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: Icon(
                      Icons.grid_view_rounded,
                      color: state.eisenhowerMatrixEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withAlpha(128),
                    ),
                    title: Text(AppLocalizations.of(context)!.eisenhowerMatrix),
                    subtitle: Text(
                      AppLocalizations.of(context)!.eisenhowerMatrixDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: state.eisenhowerMatrixEnabled,
                    onChanged: (v) => state.setEisenhowerMatrixEnabled(v),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: Icon(
                      Icons.mark_chat_unread_rounded,
                      color: state.sessionNotificationsEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withAlpha(128),
                    ),
                    title:
                        Text(AppLocalizations.of(context)!.sessionNotification),
                    subtitle: Text(
                      AppLocalizations.of(context)!
                          .sessionNotificationDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: state.sessionNotificationsEnabled,
                    onChanged: (v) => state.setSessionNotificationsEnabled(v),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(AppLocalizations.of(context)!.exportToCalendar),
                    subtitle: Text(
                      AppLocalizations.of(context)!.exportToCalendarSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
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
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  title: Text(AppLocalizations.of(context)!.deleteAccount,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                      )),
                  subtitle: Text(
                    AppLocalizations.of(context)!.deleteAccountSubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  enabled: !auth.isBusy,
                  onTap: auth.isBusy ? null : _confirmDeleteAccount,
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: _bottomScrollClearance(context)),
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

    return Material(
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
              final background = Color.lerp(
                    backgroundColor,
                    Colors.white,
                    _controller.value,
                  ) ??
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
    );
  }
}

/// Second confirmation dialog that requires typing exact phrase
class _DeleteAccountTextConfirmDialog extends StatefulWidget {
  @override
  State<_DeleteAccountTextConfirmDialog> createState() =>
      _DeleteAccountTextConfirmDialogState();
}

class _DeleteAccountTextConfirmDialogState
    extends State<_DeleteAccountTextConfirmDialog> {
  final _controller = TextEditingController();
  static const _requiredPhrase = 'I really want to delete my account';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final valid = _controller.text.trim() == _requiredPhrase;
      if (valid != _isValid) {
        setState(() => _isValid = valid);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: scheme.error,
        size: 40,
      ),
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To confirm deletion, please type:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.error.withAlpha(100)),
            ),
            child: SelectableText(
              _requiredPhrase,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type the phrase above',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _controller.text.isNotEmpty && !_isValid
                  ? 'Phrase does not match'
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isValid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Delete Forever'),
        ),
      ],
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
        vsync: this, duration: const Duration(milliseconds: 200));
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
        vsync: this, duration: const Duration(milliseconds: 200));
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
