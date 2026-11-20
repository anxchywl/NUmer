import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/session_limits.dart';
import 'time_inputs_row.dart';

class TimerTab extends StatelessWidget {
  const TimerTab({
    super.key,
    required this.course,
    required this.hCtrl,
    required this.mCtrl,
    required this.sCtrl,
    required this.hNode,
    required this.mNode,
    required this.sNode,
    required this.inputSlide,
    required this.fadeAway,
    required this.timerSlide,
    required this.isCondensed,
    required this.loadPlanned,
    required this.readInputs,
    required this.onChanged,
  });

  final Course course;
  final TextEditingController hCtrl;
  final TextEditingController mCtrl;
  final TextEditingController sCtrl;
  final FocusNode hNode;
  final FocusNode mNode;
  final FocusNode sNode;
  final Animation<Offset> inputSlide;
  final Animation<double> fadeAway;
  final Animation<Offset> timerSlide;
  final bool isCondensed;
  final Future<int?> Function() loadPlanned;
  final ValueGetter<int> readInputs;
  final VoidCallback onChanged;

  static const _dur = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return FutureBuilder<int?>(
      future: loadPlanned(),
      builder: (context, snap) {
        final planned = (snap.data ?? 0).clamp(0, kMaxSessionSeconds);
        final runningForThisCourse = state.timerRunning[course.id] ?? false;

        final elapsed = runningForThisCourse
            ? state.currentElapsedTimer(course.id).inSeconds
            : 0;
        final remaining = runningForThisCourse
            ? (planned - elapsed).clamp(0, kMaxSessionSeconds)
            : readInputs();

        return LayoutBuilder(
          builder: (context, c) {
            final kb = MediaQuery.of(context).viewInsets.bottom;
            final h = c.maxHeight;
            final usable = kb > 0 ? h - kb : h;

            double ay(double yPx) => ((yPx / h) * 2 - 1).clamp(-1.0, 1.0);

            const double gapPx = 100;
            const double hintGapPx = 84;

            final inputsY = isCondensed ? usable / 2 : h / 2;
            final timerY = inputsY + gapPx;
            final hintY = inputsY - hintGapPx;

            final inputsEnabled = !runningForThisCourse;

            return SizedBox(
              width: double.infinity,
              height: h,
              child: Stack(
                children: [
                  _hint(context, ay(hintY)),
                  _inputs(ay(inputsY), enabled: inputsEnabled),
                  _countdown(context, ay(timerY), remaining),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _hint(BuildContext context, double y) {
    return AnimatedAlign(
      alignment: Alignment(0, y),
      duration: _dur,
      curve: _curve,
      child: SizeTransition(
        sizeFactor: ReverseAnimation(fadeAway),
        axisAlignment: -1.0,
        child: FadeTransition(
          opacity: ReverseAnimation(fadeAway),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.typeTimeToStudy,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 6),
                Icon(Icons.arrow_downward, size: 18, color: Colors.grey),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputs(double y, {required bool enabled}) {
    return AnimatedAlign(
      alignment: Alignment(0, y),
      duration: _dur,
      curve: _curve,
      child: SlideTransition(
        position: inputSlide,
        child: TimeInputsRow(
          hCtrl: hCtrl,
          mCtrl: mCtrl,
          sCtrl: sCtrl,
          hNode: hNode,
          mNode: mNode,
          sNode: sNode,
          enabled: enabled,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _countdown(BuildContext context, double y, int remaining) {
    return AnimatedAlign(
      alignment: Alignment(0, y),
      duration: _dur,
      curve: _curve,
      child: FadeTransition(
        opacity: ReverseAnimation(fadeAway),
        child: SlideTransition(
          position: timerSlide,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Text(
                  formatHms(remaining),
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
    );
  }
}
