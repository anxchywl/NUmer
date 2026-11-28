import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

import 'add_time_course_picker.dart';
import 'hms_field.dart';

class AddTimeSheet extends StatefulWidget {
  const AddTimeSheet({super.key, required this.day});

  final DateTime day;

  @override
  State<AddTimeSheet> createState() => _AddTimeSheetState();
}

class _AddTimeSheetState extends State<AddTimeSheet>
    with WidgetsBindingObserver {
  final _focus = NumerSheetFocusMode();
  final _pageCtrl = PageController(viewportFraction: 0.68);
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  int _index = 0;
  bool _kbOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final nowOpen = view.viewInsets.bottom > 0;
    if (nowOpen == _kbOpen) return;
    _kbOpen = nowOpen;
    if (nowOpen) return;
    for (final controller in [_startCtrl, _endCtrl]) {
      if (controller.text.trim().isEmpty) continue;
      controller.text = normalizeHms(controller.text);
    }
  }

  void _refuse(String message, {bool close = false}) {
    showAppMessage(context, message, isError: true);
    if (close) Navigator.pop(context);
  }

  // null once the reason has been shown
  ({DateTime start, DateTime end})? _readRange() {
    final l10n = AppLocalizations.of(context)!;
    final startT = _startCtrl.text.trim().isEmpty
        ? null
        : parseHms(_startCtrl.text);
    final endT = _endCtrl.text.trim().isEmpty ? null : parseHms(_endCtrl.text);
    if (startT == null || endT == null) {
      _refuse(l10n.invalidTimeFormat(l10n.timeFormatHint));
      return null;
    }
    final start = _compose(startT);
    final end = _compose(endT);
    final now = DateTime.now();
    if (start.isAfter(now) || end.isAfter(now)) {
      _refuse(l10n.cannotEnterFutureTime, close: true);
      return null;
    }
    if (!end.isAfter(start)) {
      _refuse(l10n.startTimeLaterThanEndTime, close: true);
      return null;
    }
    return (start: start, end: end);
  }

  DateTime _compose(({int h, int m, int s}) t) {
    final day = widget.day;
    return DateTime(day.year, day.month, day.day, t.h, t.m, t.s);
  }

  Future<void> _save() async {
    final courses = context.read<AppState>().courses;
    final l10n = AppLocalizations.of(context)!;
    if (courses.isEmpty) return _refuse(l10n.addCourseFirst);
    final range = _readRange();
    if (range == null) return;

    final course = courses[_index.clamp(0, courses.length - 1).toInt()];
    try {
      await context.read<AppState>().addManualSession(
        courseId: course.id,
        start: range.start,
        end: range.end,
      );
    } on SessionOverlapException catch (_) {
      if (!mounted) return;
      return _refuse(l10n.alreadyStudiedThisPeriod, close: true);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    showAppMessage(context, l10n.timeAddedToCourse(course.name));
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    final media = MediaQuery.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: _focus.isTyping ? 0 : 380,
            maxHeight: media.size.height - media.padding.top - 80,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + media.viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _content(context),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chrome = _focus.hidesChrome;
    return [
      NumerFocusFold(hidden: chrome, child: _heading(context)),
      NumerFocusFold(
        hidden: _focus.hides('start'),
        child: HmsField(
          label: l10n.startTime,
          hint: l10n.timeFormatHint,
          controller: _startCtrl,
          focusNode: _focus.nodeFor('start'),
          textInputAction: TextInputAction.next,
          onSubmitted: () => _focus.moveTo('end'),
        ),
      ),
      NumerFocusGap(hidden: chrome, height: 10),
      NumerFocusFold(
        hidden: _focus.hides('end'),
        child: HmsField(
          label: l10n.endTime,
          hint: l10n.timeFormatHint,
          controller: _endCtrl,
          focusNode: _focus.nodeFor('end'),
          textInputAction: TextInputAction.done,
        ),
      ),
      NumerFocusFold(hidden: chrome, child: _courses(context)),
      const SizedBox(height: 14),
      SheetDoneActions(focus: _focus, actions: _saveButton(context)),
    ];
  }

  Widget _heading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: scheme.onSurfaceVariant.withAlpha((0.30 * 255).round()),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.addTime,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _courses(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(
          height: 20,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 6),
        AddTimeCoursePicker(
          courses: context.watch<AppState>().courses,
          controller: _pageCtrl,
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ],
    );
  }

  Widget _saveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: Text(AppLocalizations.of(context)!.save),
      ),
    );
  }
}
