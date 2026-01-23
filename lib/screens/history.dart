
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/storage.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_toast.dart';

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
      DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    
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
      builder: (ctx) => _SessionNotesSheet(
        initialNotes: row.notes ?? '',
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    await context.read<AppState>().saveSessionNotes(
          id: row.id,
          notes: result,
        );
    if (!mounted) return;
    showAppMessage(context, l10n.notesSaved);
    setState(() => _future = _load());
  }

  Future<void> _delete(String id, {required _SessionRow row}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteSession),
        content: Text(AppLocalizations.of(context)!.deleteSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
            Icon(Icons.filter_alt_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                builder: (_) => _AddTimeSheet(day: day),
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
          if (banner != null) banner,
          Expanded(
            child: FutureBuilder<List<_SessionRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snap.data ?? const <_SessionRow>[];
                if (sessions.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noData,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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

class _SessionNotesSheet extends StatefulWidget {
  const _SessionNotesSheet({
    required this.initialNotes,
  });

  final String initialNotes;

  @override
  State<_SessionNotesSheet> createState() => _SessionNotesSheetState();
}

class _SessionNotesSheetState extends State<_SessionNotesSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasExisting = widget.initialNotes.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.sessionNotes,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: l10n.sessionNotesHint,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              LengthLimitingTextInputFormatter(160),
              FilteringTextInputFormatter.allow(
                RegExp(r'[\p{L}\p{N} ,.]', unicode: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _controller.text),
                child: Text(hasExisting ? l10n.updateNotes : l10n.sendNotes),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
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
    l10n.jan, l10n.feb, l10n.mar, l10n.apr, l10n.mayShort, l10n.jun,
    l10n.jul, l10n.aug, l10n.sep, l10n.oct, l10n.nov, l10n.dec
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
    default:
      return 'via $kind';
  }
}




class _AddTimeSheet extends StatefulWidget {
  final DateTime day; 
  const _AddTimeSheet({required this.day});

  @override
  State<_AddTimeSheet> createState() => _AddTimeSheetState();
}

class _AddTimeSheetState extends State<_AddTimeSheet>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final PageController _pageCtrl;
  int _index = 0;

  
  final _startCtrl = TextEditingController(text: '');
  final _endCtrl = TextEditingController(text: '');

  
  bool _kbOpen = false;
  late final AnimationController _kbAnim;
  late final Animation<Offset> _titleInputsLift; 
  late final Animation<Offset> _carouselDown; 
  late final Animation<double> _carouselFade; 

  
  final GlobalKey _saveKey = GlobalKey();
  double _liftPx = 0; 

  
  static const _animDur = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;
  static const double _titleLiftY = -0.06; 
  static const double _carouselDownY = 0.22; 
  static const double _bottomGutter = 16; 

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.68);

    _kbAnim = AnimationController(vsync: this, duration: _animDur);
    final curved = CurvedAnimation(parent: _kbAnim, curve: _curve);

    _titleInputsLift = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, _titleLiftY),
    ).animate(curved);

    _carouselDown = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, _carouselDownY),
    ).animate(curved);

    _carouselFade = Tween<double>(begin: 1, end: 0).animate(curved);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    _kbAnim.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  
  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    final bottomPx = view?.viewInsets.bottom ?? 0.0;
    final dpr = view?.devicePixelRatio ??
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final bottom = bottomPx / dpr;

    final nowOpen = bottom > 0;
    if (nowOpen == _kbOpen) return;

    _kbOpen = nowOpen;
    if (_kbOpen) {
      _kbAnim.forward();
    } else {
      
      if (_startCtrl.text.trim().isNotEmpty) {
        _startCtrl.text = _normalizeHms(_startCtrl.text);
      }
      if (_endCtrl.text.trim().isNotEmpty) {
        _endCtrl.text = _normalizeHms(_endCtrl.text);
      }
      _kbAnim.reverse();
    }

    
    _scheduleRecalcLift();
    setState(() {});
  }

  void _scheduleRecalcLift() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcLiftIfNeeded());
  }

  
  void _recalcLiftIfNeeded() {
    if (!mounted) return;

    final mq = MediaQuery.of(context);
    final visibleBottom = mq.size.height - mq.viewInsets.bottom;

    final ctx = _saveKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final pos = box.localToGlobal(Offset.zero);
    final saveBottom = pos.dy + box.size.height; 

    
    final overlap = (saveBottom + _bottomGutter) - visibleBottom;
    final needed = overlap > 0 ? overlap : 0;

    
    if ((needed - _liftPx).abs() > 1.0) {
      setState(() {
        
        _liftPx = needed.clamp(0.0, mq.size.height * 0.66).toDouble();
      });
    }
  }

  
  String _normalizeHms(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    String hh = '00', mm = '00', ss = '00';
    if (d.isEmpty) return '00:00:00';
    if (d.length <= 2) {
      hh = d.padLeft(2, '0');
    } else if (d.length <= 4) {
      hh = d.substring(0, d.length - 2).padLeft(2, '0');
      mm = d.substring(d.length - 2);
    } else {
      final takeLast6 =
          d.length > 6 ? d.substring(d.length - 6) : d.padLeft(6, '0');
      hh = takeLast6.substring(0, 2);
      mm = takeLast6.substring(2, 4);
      ss = takeLast6.substring(4, 6);
    }

    int H = int.tryParse(hh) ?? 0;
    int M = int.tryParse(mm) ?? 0;
    int S = int.tryParse(ss) ?? 0;

    if (H > 23) H = 23;
    if (M > 59) M = 59;
    if (S > 59) S = 59;

    return '${H.toString().padLeft(2, '0')}:${M.toString().padLeft(2, '0')}:${S.toString().padLeft(2, '0')}';
  }

  ({int h, int m, int s})? _parseHms(String value) {
    final m =
        RegExp(r'^(\d{2}):(\d{2}):(\d{2})$').firstMatch(_normalizeHms(value));
    if (m == null) return null;
    return (
      h: int.parse(m.group(1)!),
      m: int.parse(m.group(2)!),
      s: int.parse(m.group(3)!)
    );
  }

  DateTime _compose(DateTime day, ({int h, int m, int s}) t) =>
      DateTime(day.year, day.month, day.day, t.h, t.m, t.s);

  
  Future<void> _save() async {
    final courses = context.read<AppState>().courses;
    if (courses.isEmpty) {
      showAppMessage(context, AppLocalizations.of(context)!.addCourseFirst, isError: true);
      return;
    }

    
    if (_startCtrl.text.trim().isEmpty || _endCtrl.text.trim().isEmpty) {
      showAppMessage(
        context,
        AppLocalizations.of(context)!.invalidTimeFormat(AppLocalizations.of(context)!.timeFormatHint),
        isError: true,
      );
      return;
    }

    final startT = _parseHms(_startCtrl.text);
    final endT = _parseHms(_endCtrl.text);
    if (startT == null || endT == null) {
      showAppMessage(
        context,
        AppLocalizations.of(context)!.invalidTimeFormat(AppLocalizations.of(context)!.timeFormatHint),
        isError: true,
      );
      return;
    }

    
    final start = _compose(widget.day, startT);
    final end = _compose(widget.day, endT);

    
    final nowLocal = DateTime.now();
    if (start.isAfter(nowLocal) || end.isAfter(nowLocal)) {
      showAppMessage(context, AppLocalizations.of(context)!.cannotEnterFutureTime, isError: true);
      Navigator.pop(context);
      return;
    }

    
    if (!end.isAfter(start)) {
      showAppMessage(context, AppLocalizations.of(context)!.startTimeLaterThanEndTime, isError: true);
      Navigator.pop(context);
      return;
    }

    
    final safeIndex = _index.clamp(0, courses.length - 1).toInt();
    final course = courses[safeIndex];
    try {
      await context.read<AppState>().addManualSession(
            courseId: course.id,
            start: start,
            end: end,
          );
    } on SessionOverlapException catch (_) {
      if (!mounted) return;
      showAppMessage(context, AppLocalizations.of(context)!.alreadyStudiedThisPeriod, isError: true);
      Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    showAppMessage(context, AppLocalizations.of(context)!.timeAddedToCourse(course.name));
  }

  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final courses = context.watch<AppState>().courses;

    
    _scheduleRecalcLift();

    final mq = MediaQuery.of(context);
    final maxAvailable = mq.size.height - mq.padding.top - 80;

    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: _animDur,
          curve: _curve,
          
          padding: EdgeInsets.only(bottom: _liftPx),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: 380, maxHeight: maxAvailable),
            child: AnimatedSize(
              duration: _animDur,
              curve: _curve,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                              scheme.onSurfaceVariant.withAlpha((0.30 * 255).round()),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 12),

                        
                        SlideTransition(
                          position: _titleInputsLift,
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.addTime,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              _HmsField(
                                label: AppLocalizations.of(context)!.startTime,
                                controller: _startCtrl,
                                hint: AppLocalizations.of(context)!.timeFormatHint,
                                onSubmitted: (_) => _scheduleRecalcLift(),
                              ),
                              const SizedBox(height: 10),
                              _HmsField(
                                label: AppLocalizations.of(context)!.endTime,
                                controller: _endCtrl,
                                hint: AppLocalizations.of(context)!.timeFormatHint,
                                onSubmitted: (_) => _scheduleRecalcLift(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Divider(
                            height: 20,
                            thickness: 1,
                            color: scheme.outlineVariant),

                        const SizedBox(height: 6),

                        
                        if (courses.isEmpty)
                          FadeTransition(
                            opacity: _carouselFade,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                                child: Text(AppLocalizations.of(context)!.noCoursesAvailable),
                            ),
                          )
                        else
                          SizeTransition(
                            axisAlignment: -1.0,
                            sizeFactor: _carouselFade,
                            child: FadeTransition(
                              opacity: _carouselFade,
                              child: SlideTransition(
                                position: _carouselDown,
                                child: SizedBox(
                                  height: 164,
                                  child: PageView.builder(
                                    controller: _pageCtrl,
                                    scrollDirection: Axis.vertical,
                                    onPageChanged: (i) =>
                                        setState(() => _index = i),
                                    itemCount: courses.length,
                                    itemBuilder: (context, i) {
                                      final c = courses[i];
                                      final selected = i == _index;
                                      return AnimatedScale(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        scale: selected ? 1.0 : 0.95,
                                        child: AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          opacity: selected ? 1.0 : 0.6,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 8),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color:
                                                  scheme.surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: selected
                                                    ? scheme.primary
                                                      .withAlpha((0.40 * 255).round())
                                                    : scheme.outlineVariant,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: c.color),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    c.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        
                        SizedBox(
                          key: _saveKey,
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save),
                            label: Text(AppLocalizations.of(context)!.save),
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
      ),
    );
  }
}


class _HmsAutoColonFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    const max = 6; 
    final take = digits.length > max ? digits.substring(0, max) : digits;

    final buf = StringBuffer();
    for (int i = 0; i < take.length; i++) {
      if (i == 2 || i == 4) buf.write(':'); 
      buf.write(take[i]);
    }
    final formatted = buf.toString();

    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _HmsField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  const _HmsField({
    required this.label,
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  @override
  State<_HmsField> createState() => _HmsFieldState();
}

class _HmsFieldState extends State<_HmsField> {
  void _normalizeNow() {
    final state = context.findAncestorStateOfType<_AddTimeSheetState>();
    final raw = widget.controller.text.trim();
    if (state == null || raw.isEmpty) return;

    
    final normalized = state._normalizeHms(raw);
    widget.controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      textInputAction: widget.label.toLowerCase() == 'end'
          ? TextInputAction.done
          : TextInputAction.next,

      
      onChanged: (_) {},

      
      onSubmitted: (v) {
        _normalizeNow();
        widget.onSubmitted?.call(widget.controller.text);
      },
      onEditingComplete: _normalizeNow,

      
      inputFormatters: [
        _HmsAutoColonFormatter(),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint, 
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: theme.textTheme.bodyLarge,
    );
  }
}
