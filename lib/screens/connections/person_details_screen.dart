import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/models/person.dart';
import 'package:numer_app/models/contact_group.dart';
import 'package:numer_app/services/auth_service.dart';
import 'package:numer_app/services/connections_service.dart';
import 'package:numer_app/screens/connections/add_person_sheet.dart';

class PersonDetailsScreen extends StatefulWidget {
  final String personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  final TextEditingController _interactionNoteController = TextEditingController();
  bool _isAddingInteraction = false;

  @override
  void dispose() {
    _interactionNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme is accessed inside Consumer for proper context

    return Consumer<ConnectionsService>(
      builder: (context, service, _) {
        final person = service.getPersonById(widget.personId);
        
        if (person == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.personNameLabel)),
            body: Center(
              child: Text(AppLocalizations.of(context)!.personNotFound),
            ),
          );
        }

        final groups = service.groups
            .where((g) => person.groupIds.contains(g.id))
            .toList();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar with actions
              SliverAppBar.large(
                title: Text(person.name),
                actions: [
                  // Quick action buttons
                  if (person.phone != null && person.phone!.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.phone_outlined),
                      tooltip: 'Call',
                      onPressed: () => _makeCall(person.phone!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.message_outlined),
                      tooltip: 'Message',
                      onPressed: () => _sendMessage(person.phone!),
                    ),
                  ],
                  if (person.email != null && person.email!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.email_outlined),
                      tooltip: 'Email',
                      onPressed: () => _sendEmail(person.email!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: AppLocalizations.of(context)!.edit,
                      onPressed: () => _editPerson(context, person),
                    ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeletePerson(context, person);
                      }
                    },
                  ),
                ],
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mark Contacted Today Button
                      FilledButton.icon(
                        onPressed: () => _markContactedToday(context, person.id),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(AppLocalizations.of(context)!.markContactedToday),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Contact Info Card
                      _buildInfoCard(context, person, groups),
                      
                      const SizedBox(height: 24),
                      
                      // Interaction Log Section
                      _buildInteractionLogSection(context, person),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(BuildContext context, Person person, List<ContactGroup> groups) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: colorScheme.outlineVariant.withAlpha(77))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Groups
          if (groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.groupsLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: groups.map((group) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: group.color.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: group.color.withAlpha(77)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(group.icon, size: 14, color: group.color),
                          const SizedBox(width: 4),
                          Text(
                            group.name,
                            style: TextStyle(
                              color: group.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          
          // Tags
          if (person.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.tagsLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: person.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          
          const Divider(height: 1),
          
          // Contact Details
          if (person.phone != null && person.phone!.isNotEmpty)
            _buildInfoRow(
              context,
              icon: Icons.phone_outlined,
              label: AppLocalizations.of(context)!.phoneLabel,
              value: person.phone!,
              onTap: () => _makeCall(person.phone!),
            ),
          
          if (person.email != null && person.email!.isNotEmpty)
            _buildInfoRow(
              context,
              icon: Icons.email_outlined,
              label: AppLocalizations.of(context)!.emailLabel,
              value: person.email!,
              onTap: () => _sendEmail(person.email!),
            ),
          
          if (person.birthday != null)
            _buildInfoRow(
              context,
              icon: Icons.cake_outlined,
              label: 'Birthday', // TODO: Localize
              value: DateFormat.yMMMd().format(person.birthday!),
            ),
          
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_outlined,
            label: AppLocalizations.of(context)!.lastContactedLabel,
            value: person.lastContactedAt != null
                ? DateFormat.yMMMd().format(person.lastContactedAt!)
                : 'Not recorded', // TODO: add to arb if needed
            valueColor: person.needsFollowUp ? colorScheme.error : null,
          ),
          
          if (person.notes != null && person.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.notesLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    person.notes!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionLogSection(BuildContext context, Person person) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sortedLog = [...person.interactionLog]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: colorScheme.outlineVariant.withAlpha(77))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.interactionLogTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isAddingInteraction ? Icons.close : Icons.add,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isAddingInteraction = !_isAddingInteraction;
                      if (!_isAddingInteraction) {
                        _interactionNoteController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Add interaction form
          if (_isAddingInteraction)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _interactionNoteController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.addInteractionHint,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(128),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isAddingInteraction = false;
                            _interactionNoteController.clear();
                          });
                        },
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _addInteraction(context, person.id),
                        child: Text(AppLocalizations.of(context)!.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          const Divider(height: 1),
          
          // Log entries
          if (sortedLog.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withAlpha(128),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.noInteractionsYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedLog.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = sortedLog[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMd().add_jm().format(entry.date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.note,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _editPerson(BuildContext context, Person person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddPersonSheet(person: person),
    );
  }

  Future<void> _markContactedToday(BuildContext context, String personId) async {
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    
    final service = context.read<ConnectionsService>();
    await service.markContactedToday(uid, personId);
    
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.markContactedToday),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addInteraction(BuildContext context, String personId) async {
    final note = _interactionNoteController.text.trim();
    if (note.isEmpty) return;
    
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    
    final service = context.read<ConnectionsService>();
    final now = DateTime.now();
    
    final entry = InteractionEntry(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      note: note,
      createdAt: now,
    );
    
    await service.addInteraction(uid, personId, entry);
    
    setState(() {
      _isAddingInteraction = false;
      _interactionNoteController.clear();
    });
  }

  Future<void> _confirmDeletePerson(BuildContext context, Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteContactTitle),
        content: Text(AppLocalizations.of(context)!.deleteContactMessage(person.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      final auth = context.read<AuthController>();
      final uid = auth.currentUser?.uid;
      if (uid == null) return;
      
      final service = context.read<ConnectionsService>();
      await service.deletePerson(uid, person.id);
      
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendMessage(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
