import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_ui/numer_ui.dart';

import '../widgets/add_time_sheet.dart';
import '../widgets/session_notes_sheet.dart';

class HistoryScreen extends StatefulWidget {
  final DateTime? startLocal;
  final DateTime? endLocal;
  final String? courseId;

  const HistoryScreen({
    super.key,
    this.startLocal,
    this.endLocal,
    this.courseId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<_SessionRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  DateTime? _asDT(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aEnd.isAfter(bStart) && aStart.isBefore(bEnd);
  }

  Future<List<_SessionRow>> _load() async {
    final appState = context.read<AppState>();
    final courses = appState.courses;
    final byId = {for (final c in courses) c.id: c};

    final raw = await Storage.listSessions();

    final rows = <_SessionRow>[];

    final hasRange = widget.startLocal != null && widget.endLocal != null;
    final filterStart = widget.startLocal;
    final filterEnd = widget.endLocal;
    final filterCourseId = widget.courseId;

    for (final m in raw) {
      final id = (m['id'] as String?) ?? '';
      final courseId = (m['courseId'] as String?) ?? '';
      final kind = (m['kind'] as String?) ?? '';
      final notes = m['notes'] as String?;

      final start =
          _asDT(m['startLocal']) ?? _asDT(m['startUtc']) ?? _asDT(m['start']);
      final end = _asDT(m['endLocal']) ?? _asDT(m['endUtc']) ?? _asDT(m['end']);
      if (id.isEmpty || start == null || end == null) continue;

      if (filterCourseId != null &&
          filterCourseId.isNotEmpty &&
          courseId != filterCourseId) {
        continue;
      }
      if (hasRange && filterStart != null && filterEnd != null) {
        if (!_overlaps(start, end, filterStart, filterEnd)) continue;
      }

      final course = byId[courseId];
      rows.add(
        _SessionRow(
          id: id,
          courseId: courseId,
          courseName: course?.name ?? 'Unknown',
          courseColor: course?.color ?? Colors.grey.shade400,
          start: start,
          end: end,
          kind: kind,
          notes: notes,
        ),
      );
    }

    rows.sort((a, b) => b.start.compareTo(a.start));
    return rows;
  }

  Future<void> _editNotes(_SessionRow row) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SessionNotesSheet(initialNotes: row.notes ?? ''),
    );
    if (result == null) return;
    if (!mounted) return;
    await context.read<AppState>().saveSessionNotes(id: row.id, notes: result);
    if (!mounted) return;
    showAppMessage(context, l10n.notesSaved);
    setState(() => _future = _load());
  }

  Future<void> _delete(String id, {required _SessionRow row}) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showNumerConfirm(
      context,
      title: l10n.deleteSession,
      body: l10n.deleteSessionMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;

    final appState = context.read<AppState>();
    await appState.deleteSession(
      id: id,
      courseId: row.courseId,
      startLocal: row.start,
      endLocal: row.end,
    );

    if (!mounted) return;

    setState(() {
      _future = _future.then((current) {
        final updated = List<_SessionRow>.from(current);
        updated.removeWhere((e) => e.id == id);
        return updated;
      });
    });

    showAppMessage(context, AppLocalizations.of(context)!.sessionDeleted);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<AppState>().courses;
    final byId = {for (final c in courses) c.id: c};

    Widget? banner;
    if (widget.startLocal != null && widget.endLocal != null) {
      final labelDate = _fmtDateOnly(context, widget.startLocal!);
      final courseName =
          (widget.courseId != null && byId[widget.courseId!] != null)
          ? byId[widget.courseId!]!.name
          : null;

      banner = Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                courseName == null ? labelDate : '$labelDate • $courseName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.history,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.addTime,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final base = widget.startLocal ?? DateTime.now();
              final day = DateTime(base.year, base.month, base.day);

              final added = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => AddTimeSheet(day: day),
              );

              if (mounted && added == true) {
                setState(() => _future = _load());
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ?banner,
          Expanded(
            child: FutureBuilder<List<_SessionRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const NumerSkeleton();
                }
                final sessions = snap.data ?? const <_SessionRow>[];
                if (sessions.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noData,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    final duration = s.end.difference(s.start).inSeconds;

                    return _HistoryCard(
                      color: s.courseColor,
                      title: s.courseName,
                      timeLine:
                          '${_fmtDateTime(s.start)} ➜ ${_fmtDateTime(s.end)}',
                      metaLine:
                          '${AppLocalizations.of(context)!.total}: ${_fmtHMS(duration)}'
                          '${s.kind.isNotEmpty ? ' • ${_kindLabel(context, s.kind)}' : ''}',
                      hasNotes: (s.notes ?? '').trim().isNotEmpty,
                      onNotes: () => _editNotes(s),
                      onDelete: () => _delete(s.id, row: s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Color color;
  final String title;
  final String timeLine;
  final String metaLine;
  final bool hasNotes;
  final VoidCallback onNotes;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.color,
    required this.title,
    required this.timeLine,
    required this.metaLine,
    required this.hasNotes,
    required this.onNotes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            minLeadingWidth: 20,
            leading: _ColorDot(color: color),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metaLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (context.watch<AppState>().quickNotesEnabled)
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.sessionNotes,
                    icon: Icon(
                      hasNotes
                          ? Icons.sticky_note_2_outlined
                          : Icons.note_add_outlined,
                    ),
                    onPressed: onNotes,
                    splashRadius: 22,
                  ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.delete,
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  splashRadius: 22,
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SessionRow {
  final String id;
  final String courseId;
  final String courseName;
  final Color courseColor;
  final DateTime start;
  final DateTime end;
  final String kind;
  final String? notes;

  _SessionRow({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseColor,
    required this.start,
    required this.end,
    required this.kind,
    required this.notes,
  });
}

String _fmtHMS(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}

String _fmtDateOnly(BuildContext context, DateTime d) {
  final l10n = AppLocalizations.of(context)!;
  final months = [
    l10n.jan,
    l10n.feb,
    l10n.mar,
    l10n.apr,
    l10n.mayShort,
    l10n.jun,
    l10n.jul,
    l10n.aug,
    l10n.sep,
    l10n.oct,
    l10n.nov,
    l10n.dec,
  ];
  final mm = months[d.month - 1];
  final day = d.day.toString().padLeft(2, '0');
  return '$mm $day, ${d.year}';
}

String _fmtDateTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  final s = d.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _kindLabel(BuildContext context, String kind) {
  final l10n = AppLocalizations.of(context)!;
  switch (kind.toLowerCase()) {
    case 'timer':
      return l10n.viaTimer;
    case 'stopwatch':
      return l10n.viaStopwatch;
    case 'pomodoro':
      return l10n.viaPomodoro;
    case 'manual recording':
      return l10n.viaManualRecording;
    default:
      return '${l10n.via} $kind';
  }
}
