import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/connections/models/person.dart';
import 'package:numer_app/features/connections/data/connections_service.dart';

class PeopleCalendarScreen extends StatefulWidget {
  const PeopleCalendarScreen({super.key});

  @override
  State<PeopleCalendarScreen> createState() => _PeopleCalendarScreenState();
}

class _PeopleCalendarScreenState extends State<PeopleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.interactionCalendarTitle),
      ),
      body: Consumer<ConnectionsService>(
        builder: (context, service, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeatmapCalendar(context, service),
              ),
              if(_selectedDay != null)
                 _buildDayDetails(context, service, _selectedDay!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeatmapCalendar(BuildContext context, ConnectionsService service) {
    // 1. Pre-calculate interaction counts per day
    final interactionsPerDay = <DateTime, int>{};
    for (final person in service.people) {
      for (final interaction in person.interactionLog) {
         final dateKey = DateTime(interaction.date.year, interaction.date.month, interaction.date.day);
         interactionsPerDay[dateKey] = (interactionsPerDay[dateKey] ?? 0) + 1;
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365 * 2)),
          lastDay: DateTime.now(),
          focusedDay: _focusedDay,
          currentDay: DateTime.now(),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return _buildCalendarCell(context, day, interactionsPerDay);
            },
            todayBuilder: (context, day, focusedDay) {
               return _buildCalendarCell(context, day, interactionsPerDay, isToday: true);
            },
             selectedBuilder: (context, day, focusedDay) {
               return _buildCalendarCell(context, day, interactionsPerDay, isSelected: true);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCell(
    BuildContext context, 
    DateTime day, 
    Map<DateTime, int> interactions, 
    {bool isToday = false, bool isSelected = false}
  ) {
      final dateKey = DateTime(day.year, day.month, day.day);
      final count = interactions[dateKey] ?? 0;
      final hasInteractions = count > 0;
      
      Color? cellColor;
      if (hasInteractions) {
         // Visualize intensity
         final alpha = ((0.2 + (count * 0.15)).clamp(0.2, 1.0) * 255).toInt();
         cellColor = Theme.of(context).colorScheme.primary.withAlpha(alpha);
      }

      BoxDecoration decoration = BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary : cellColor,
        shape: BoxShape.circle,
        border: isToday && !isSelected 
          ? Border.all(color: Theme.of(context).colorScheme.primary) 
          : null,
      );

      TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;
       if (isSelected || (hasInteractions && count > 3)) { // Ensure contrast
        textStyle = textStyle?.copyWith(color: Theme.of(context).colorScheme.onPrimary);
      }

      return Center(
        child: Container(
          margin: const EdgeInsets.all(6.0),
          alignment: Alignment.center,
          decoration: decoration,
          child: Text(
            '${day.day}',
            style: textStyle,
          ),
        ),
      );
  }

  Widget _buildDayDetails(BuildContext context, ConnectionsService service, DateTime date) {
      
      // Find interactions for this day
      final dailyInteractions = <Map<String, dynamic>>[];
      
      for (final person in service.people) {
        for (final interaction in person.interactionLog) {
           if (isSameDay(interaction.date, date)) {
             dailyInteractions.add({
               'person': person,
               'interaction': interaction,
             });
           }
        }
      }

      if (dailyInteractions.isEmpty) {
         return SliverToBoxAdapter(
           child: Padding(
             padding: const EdgeInsets.all(32),
             child: Center(
               child: Text(
                 'No interactions on this day',
                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                 ),
               ),
             ),
           ),
         );
      }

      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = dailyInteractions[index];
              final person = item['person'] as Person;
              final interaction = item['interaction'] as InteractionEntry;

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    person.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(interaction.note.isNotEmpty ? interaction.note : 'Contacted'),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                     child: Text(person.name.substring(0,1).toUpperCase()),
                  ),
                ),
              );
            },
            childCount: dailyInteractions.length,
          ),
        ),
      );
  }
}
