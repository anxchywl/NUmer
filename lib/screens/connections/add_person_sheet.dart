import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

import '../../models/person.dart';
import '../../services/auth_service.dart';
import '../../services/connections_service.dart';

class AddPersonSheet extends StatefulWidget {
  final Person? person; // For editing existing person

  const AddPersonSheet({super.key, this.person});

  @override
  State<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  
  Set<String> _selectedGroupIds = {};
  DateTime? _lastContactedAt;
  bool _remindToReachOut = false;
  bool _isSaving = false;

  bool get _isEditing => widget.person != null;

  @override
  void initState() {
    super.initState();
    
    final person = widget.person;
    _nameController = TextEditingController(text: person?.name ?? '');
    _phoneController = TextEditingController(text: person?.phone ?? '');
    _emailController = TextEditingController(text: person?.email ?? '');
    _notesController = TextEditingController(text: person?.notes ?? '');
    _tagsController = TextEditingController(text: person?.tags.join(', ') ?? '');
    _selectedGroupIds = person?.groupIds.toSet() ?? {};
    _lastContactedAt = person?.lastContactedAt;
    _remindToReachOut = person?.remindToReachOut ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = context.watch<ConnectionsService>();
    final groups = service.groups;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing 
                          ? AppLocalizations.of(context)!.editPersonTitle 
                          : AppLocalizations.of(context)!.addPersonTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name (required)
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          label: AppLocalizations.of(context)!.personNameLabel,
                          hint: AppLocalizations.of(context)!.personNameHint,
                          icon: Icons.person_outline,
                          theme: theme,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.nameRequired;
                          }
                          return null;
                        },
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(64),
                        ],
                        textCapitalization: TextCapitalization.words,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Groups (multi-select)
                      Text(
                        AppLocalizations.of(context)!.groupsLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      if (groups.isEmpty)
                        Text(
                          'No groups yet. Create one in group management.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: groups.map((group) {
                            final isSelected = _selectedGroupIds.contains(group.id);
                            return FilterChip(
                              label: Text(group.name),
                              selected: isSelected,
                              selectedColor: group.color.withAlpha(51),
                              avatar: isSelected
                                  ? null
                                  : CircleAvatar(
                                      backgroundColor: group.color.withAlpha(51),
                                      child: Icon(
                                        group.icon,
                                        size: 14,
                                        color: group.color,
                                      ),
                                    ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedGroupIds.add(group.id);
                                  } else {
                                    _selectedGroupIds.remove(group.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Tags
                      TextFormField(
                        controller: _tagsController,
                        decoration: _inputDecoration(
                          label: AppLocalizations.of(context)!.tagsLabel,
                          hint: 'e.g., mentor, networking, coffee',
                          icon: Icons.tag,
                          theme: theme,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(128),
                        ],
                      ),
                      Text(
                        'Separate tags with commas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: _inputDecoration(
                          label: AppLocalizations.of(context)!.phoneLabel,
                          hint: 'Enter phone number',
                          icon: Icons.phone_outlined,
                          theme: theme,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(20),
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-+().]')),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration(
                          label: AppLocalizations.of(context)!.emailLabel,
                          hint: 'Enter email address',
                          icon: Icons.email_outlined,
                          theme: theme,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(128),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: _inputDecoration(
                          label: AppLocalizations.of(context)!.notesLabel,
                          hint: 'Add any notes about this person...',
                          icon: Icons.notes_outlined,
                          theme: theme,
                        ),
                        maxLines: 3,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Last Contacted
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.calendar_today_outlined,
                          color: colorScheme.primary,
                        ),
                        title: Text(AppLocalizations.of(context)!.lastContactedLabel),
                        subtitle: Text(
                          _lastContactedAt != null
                              ? DateFormat.yMMMd().format(_lastContactedAt!)
                              : 'Not set',
                          style: TextStyle(
                            color: _lastContactedAt != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_lastContactedAt != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() => _lastContactedAt = null);
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar),
                              onPressed: () => _selectDate(context),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Remind me toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppLocalizations.of(context)!.remindMeLabel),
                        subtitle: Text(
                          'Coming soon',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        value: _remindToReachOut,
                        onChanged: null, // Disabled for now
                        secondary: Icon(
                          Icons.notifications_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Save Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing 
                        ? AppLocalizations.of(context)!.saveChanges 
                        : AppLocalizations.of(context)!.addPersonTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastContactedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    
    if (picked != null) {
      setState(() => _lastContactedAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final auth = context.read<AuthController>();
      final uid = auth.currentUser?.uid;
      if (uid == null) return;
      
      final service = context.read<ConnectionsService>();
      final now = DateTime.now();
      
      // Parse tags
      final tagsText = _tagsController.text.trim();
      final tags = tagsText.isNotEmpty
          ? tagsText.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];
      
      if (_isEditing) {
        // Update existing person
        final updatedPerson = widget.person!.copyWith(
          name: _nameController.text.trim(),
          groupIds: _selectedGroupIds.toList(),
          tags: tags,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          lastContactedAt: _lastContactedAt,
          remindToReachOut: _remindToReachOut,
          updatedAt: now,
        );
        
        await service.updatePerson(uid, updatedPerson);
      } else {
        // Create new person
        final newPerson = Person(
          id: now.millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          groupIds: _selectedGroupIds.toList(),
          tags: tags,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          lastContactedAt: _lastContactedAt,
          remindToReachOut: _remindToReachOut,
          createdAt: now,
          updatedAt: now,
        );
        
        await service.addPerson(uid, newPerson);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSaving(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
