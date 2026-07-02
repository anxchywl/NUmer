import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:numer_app/features/connections/models/person.dart';
import 'package:numer_app/features/connections/models/contact_group.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final List<ContactGroup> groups;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onEmail;

  const PersonCard({
    super.key,
    required this.person,
    required this.groups,
    this.onTap,
    this.onCall,
    this.onMessage,
    this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasQuickActions = onCall != null || onMessage != null || onEmail != null;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withAlpha(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? colorScheme.outlineVariant.withAlpha(77)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Name + Quick Actions
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (person.lastContactedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatLastContacted(person.lastContactedAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: person.needsFollowUp
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Quick Action Icons
                  if (hasQuickActions) ...[
                    if (onCall != null)
                      IconButton(
                        icon: Icon(Icons.phone_outlined, color: colorScheme.primary),
                        onPressed: onCall,
                        tooltip: 'Call',
                        visualDensity: VisualDensity.compact,
                      ),
                    if (onMessage != null)
                      IconButton(
                        icon: Icon(Icons.message_outlined, color: colorScheme.primary),
                        onPressed: onMessage,
                        tooltip: 'Message',
                        visualDensity: VisualDensity.compact,
                      ),
                    if (onEmail != null)
                      IconButton(
                        icon: Icon(Icons.email_outlined, color: colorScheme.primary),
                        onPressed: onEmail,
                        tooltip: 'Email',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ],
              ),
              
              // Group Chips
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groups.map((group) => _GroupChip(group: group)).toList(),
                ),
              ],
              
              // Tags (if any)
              if (person.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: person.tags.take(5).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
              // Needs Follow-up Indicator
              if (person.needsFollowUp) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Haven't contacted in 30+ days",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastContacted(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Contacted today';
    } else if (diff.inDays == 1) {
      return 'Contacted yesterday';
    } else if (diff.inDays < 7) {
      return 'Contacted ${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Contacted ${weeks}w ago';
    } else {
      return 'Last: ${DateFormat.MMMd().format(date)}';
    }
  }
}

class _GroupChip extends StatelessWidget {
  final ContactGroup group;

  const _GroupChip({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: group.color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: group.color.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            group.icon,
            size: 12,
            color: group.color,
          ),
          const SizedBox(width: 4),
          Text(
            group.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: group.color,
            ),
          ),
        ],
      ),
    );
  }
}
