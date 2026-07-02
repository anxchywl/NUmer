import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/course.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

class TimerScreen extends StatefulWidget {
  
  
  final String? courseId;

  const TimerScreen({super.key, this.courseId});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _ticker;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCourseId == null) {
      final state = context.read<AppState>();
      _selectedCourseId = widget.courseId ??
          (state.courses.length == 1 ? state.courses.first.id : null);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;

    if (courses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.studyTimer)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.noCoursesYet),
        ),
      );
    }

    if (_selectedCourseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.studyTimer)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.chooseACourse,
                border: const OutlineInputBorder(),
              ),
              initialValue: _selectedCourseId,
              items: courses
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCourseId = v),
            ),
          ),
        ),
      );
    }

    final cid = _selectedCourseId!;
    final d = state.currentElapsedTimer(cid);
    final isRunning = state.timerRunning[cid] ?? false;

    
    final hasAnyActive = state.hasAnyActiveSession;
    final activeKind = state.activeSessionKind; 

    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes % 60);
    final s = two(d.inSeconds % 60);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(AppLocalizations.of(context)!.studyTimer),
            const SizedBox(width: 12),
            Flexible(
              child: _CourseChipPicker(
                selectedId: cid,
                onChanged: (newId) => setState(() => _selectedCourseId = newId),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          
          if (hasAnyActive && !(isRunning))
            MaterialBanner(
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              leading: Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              content: Text(
                AppLocalizations.of(context)!.anotherSessionRunningSilly(activeKind ?? AppLocalizations.of(context)!.session),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                     ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  },
                  child: Text(
                    AppLocalizations.of(context)!.ok,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$h:$m:$s',
                    style: const TextStyle(
                      fontSize: 48,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: [
                      
                      FilledButton.icon(
                        onPressed: isRunning
                            ? null
                            : () {
                                final ok = context.read<AppState>().startTimer(cid);
                                if (!ok) {
                                  final st = context.read<AppState>();
                                  final kind = st.activeSessionKind ?? 'session';
                                  showAppMessage(
                                    context,
                                    AppLocalizations.of(context)!.anotherSessionRunningSilly(kind),
                                    isError: true,
                                  );
                                }
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: Text(AppLocalizations.of(context)!.start),
                      ),

                      
                      FilledButton.icon(
                        onPressed: isRunning
                            ? () async {
                                final state = context.read<AppState>();
                                await state.stopTimer(cid);
                              }
                            : null,
                        icon: const Icon(Icons.stop),
                        label: Text(AppLocalizations.of(context)!.stop),
                      ),

                      
                      OutlinedButton.icon(
                        onPressed: () async {
                          
                          final st = context.read<AppState>(); 
                          final running = st.timerRunning[cid] == true;

                          if (running) {
                            await st.stopTimer(cid);

                            
                            if (!context.mounted) return;

                            showAppMessage(context, AppLocalizations.of(context)!.timerStoppedAndSaved);
                          } else {
                            
                            if (!context.mounted) return;
                            showAppMessage(context, AppLocalizations.of(context)!.nothingToReset);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.reset),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseChipPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _CourseChipPicker({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;

    if (courses.length <= 1) {
      final Course c = courses.first;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: c.color),
            const SizedBox(width: 6),
            Text(c.name, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedId,
        isDense: true,
        items: courses
            .map(
              (c) => DropdownMenuItem<String>(
                value: c.id,
                child: Row(
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: c.color),
                    const SizedBox(width: 8),
                    Text(c.name),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}