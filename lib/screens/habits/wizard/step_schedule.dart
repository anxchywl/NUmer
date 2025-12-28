import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HabitScheduleStep extends StatelessWidget {
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  const HabitScheduleStep({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("When do you want to start?", style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          
          ListTile(
            title: const Text("Start Date"),
            subtitle: Text(DateFormat.yMMMd().format(startDate)),
            leading: const Icon(Icons.calendar_today),
            tileColor: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onStartDateChanged(picked);
            },
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Text("Set an end date?", style: theme.textTheme.titleMedium),
              const Spacer(),
              Switch(
                value: endDate != null,
                onChanged: (val) {
                  onEndDateChanged(val ? startDate.add(const Duration(days: 30)) : null);
                },
              ),
            ],
          ),
          
          if (endDate != null) ...[
            const SizedBox(height: 16),
             ListTile(
              title: const Text("End Date"),
              subtitle: Text(DateFormat.yMMMd().format(endDate!)),
              leading: const Icon(Icons.event_busy),
              tileColor: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate!,
                  firstDate: startDate,
                  lastDate: startDate.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) onEndDateChanged(picked);
              },
            ),
          ],
        ],
      ),
    );
  }
}
