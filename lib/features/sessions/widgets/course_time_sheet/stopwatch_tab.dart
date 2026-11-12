import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/session_limits.dart';

class StopwatchTab extends StatelessWidget {
  const StopwatchTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final elapsed = state
        .currentElapsedStopwatch(course.id)
        .inSeconds
        .clamp(0, kMaxSessionSeconds);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatHms(elapsed),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.maxTime,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
