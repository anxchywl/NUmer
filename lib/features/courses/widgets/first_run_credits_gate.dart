import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/storage.dart';

import 'add_course_sheet.dart';

class FirstRunCreditsGate extends StatefulWidget {
  const FirstRunCreditsGate({super.key});

  @override
  State<FirstRunCreditsGate> createState() => _FirstRunCreditsGateState();
}

class _FirstRunCreditsGateState extends State<FirstRunCreditsGate> {
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
        await showAddCourseSheet(context);
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

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
