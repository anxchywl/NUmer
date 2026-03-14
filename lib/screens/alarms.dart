import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  bool _fabVisible = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms & Reminders')),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse && _fabVisible) {
            setState(() => _fabVisible = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_fabVisible) {
            setState(() => _fabVisible = true);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: state.alarms.length,
          itemBuilder: (c, i) {
            final a = state.alarms[i];
            final t = TimeOfDay.fromDateTime(a.time);
            final when =
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            return Dismissible(
              key: ValueKey(a.id),
              background: Container(color: Colors.redAccent),
              onDismissed: (_) => state.removeAlarm(a.id),
              child: ListTile(
                title: Text(a.title),
                subtitle:
                    Text(a.repeatsDaily ? 'Daily at $when' : a.time.toString()),
              ),
            );
          },
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutQuart,
        offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutQuart,
          opacity: _fabVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_fabVisible,
            child: FloatingActionButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _AddAlarmSheet(),
              ),
              child: const Icon(Icons.add_alert),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddAlarmSheet extends StatefulWidget {
  const _AddAlarmSheet();

  @override
  State<_AddAlarmSheet> createState() => _AddAlarmSheetState();
}

class _AddAlarmSheetState extends State<_AddAlarmSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(minutes: 2));
  bool _daily = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
      left: 16,
      right: 16,
      top: 16,
    );
    return Padding(
      padding: pad,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add reminder', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _date = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _date.hour,
                              _date.minute,
                            ));
                      }
                    },
                    child: Text(
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: TimeOfDay.fromDateTime(_date));
                      if (t != null) {
                        setState(() => _date = DateTime(
                              _date.year,
                              _date.month,
                              _date.day,
                              t.hour,
                              t.minute,
                            ));
                      }
                    },
                    child: Text(
                        '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Repeat daily (ignores date)'),
              value: _daily,
              onChanged: (v) => setState(() => _daily = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final id = context.read<AppState>().nextAlarmId();
                final item = AlarmItem(
                  id: id,
                  title: _title.text.trim(),
                  time: _date,
                  repeatsDaily: _daily,
                );
                await context.read<AppState>().addAlarm(item);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
