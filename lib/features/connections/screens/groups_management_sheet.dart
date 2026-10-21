import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/connections/models/contact_group.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/connections/data/connections_service.dart';

class GroupsManagementSheet extends StatefulWidget {
  const GroupsManagementSheet({super.key});

  @override
  State<GroupsManagementSheet> createState() => _GroupsManagementSheetState();
}

class _GroupsManagementSheetState extends State<GroupsManagementSheet> {
  bool _isCreating = false;
  String? _editingGroupId;

  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  IconData _selectedIcon = Icons.group;

  static const List<Color> _colorChoices = [
    Color(0xFF4285F4), // Google Blue
    Color(0xFF34A853), // Google Green
    Color(0xFFEA4335), // Google Red
    Color(0xFFFBBC04), // Google Yellow
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF00BCD4), // Cyan
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
  ];

  static const List<IconData> _iconChoices = [
    Icons.group,
    Icons.work,
    Icons.school,
    Icons.home,
    Icons.favorite,
    Icons.star,
    Icons.sports,
    Icons.music_note,
    Icons.restaurant,
    Icons.flight,
    Icons.local_cafe,
    Icons.fitness_center,
    Icons.code,
    Icons.brush,
    Icons.camera,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = context.watch<ConnectionsService>();
    final groups = service.groups;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    AppLocalizations.of(context)!.manageGroupsTitle,
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

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Existing Groups
                ...groups.map((group) => _buildGroupTile(context, group)),

                // Create New Group Section
                if (_isCreating)
                  _buildCreateForm(context)
                else
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.add,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(AppLocalizations.of(context)!.createGroup),
                    onTap: () {
                      setState(() {
                        _isCreating = true;
                        _editingGroupId = null;
                        _nameController.clear();
                        _selectedColor = _colorChoices.first;
                        _selectedIcon = _iconChoices.first;
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, ContactGroup group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = _editingGroupId == group.id;

    if (isEditing) {
      return _buildEditForm(context, group);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: group.color.withAlpha(51),
        child: Icon(
          group.icon,
          color: group.color,
          size: 20,
        ),
      ),
      title: Text(group.name),
      subtitle: group.isDefault
          ? Text(
              'Default group',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          : null,
      trailing: group.isDefault
          ? null
          : PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.renameGroup),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.delete,
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  setState(() {
                    _editingGroupId = group.id;
                    _isCreating = false;
                    _nameController.text = group.name;
                    _selectedColor = group.color;
                    _selectedIcon = group.icon;
                  });
                } else if (value == 'delete') {
                  _confirmDeleteGroup(context, group);
                }
              },
            ),
    );
  }

  Widget _buildCreateForm(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context)!.newGroup,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Name input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.groupNameLabel,
              hintText: AppLocalizations.of(context)!.groupNameHint,
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
            inputFormatters: [
              LengthLimitingTextInputFormatter(32),
            ],
          ),

          const SizedBox(height: 16),

          // Color picker
          Text(AppLocalizations.of(context)!.color,
              style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorChoices.length,
              itemBuilder: (context, index) {
                final color = _colorChoices[index];
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 16,
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Icon picker
          Text('Icon', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _iconChoices.length,
              itemBuilder: (context, index) {
                final icon = _iconChoices[index];
                final isSelected = _selectedIcon == icon;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedColor.withAlpha(51)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? _selectedColor
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? _selectedColor
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCreating = false;
                    _nameController.clear();
                  });
                },
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed:
                    _nameController.text.trim().isEmpty ? null : _createGroup,
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, ContactGroup group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context)!.editGroup,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Name input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.groupNameLabel,
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
            inputFormatters: [
              LengthLimitingTextInputFormatter(32),
            ],
          ),

          const SizedBox(height: 16),

          // Color picker
          Text(AppLocalizations.of(context)!.color,
              style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorChoices.length,
              itemBuilder: (context, index) {
                final color = _colorChoices[index];
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 16,
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Icon picker
          Text('Icon',
              style: theme.textTheme.labelMedium), // TODO: add to arb if needed
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _iconChoices.length,
              itemBuilder: (context, index) {
                final icon = _iconChoices[index];
                final isSelected = _selectedIcon == icon;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedColor.withAlpha(51)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? _selectedColor
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? _selectedColor
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _editingGroupId = null;
                    _nameController.clear();
                  });
                },
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _nameController.text.trim().isEmpty
                    ? null
                    : () => _saveGroup(group),
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final service = context.read<ConnectionsService>();
    final now = DateTime.now();

    final newGroup = ContactGroup(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: _selectedColor.toARGB32(),
      iconCodePoint: _selectedIcon.codePoint,
      createdAt: now,
      updatedAt: now,
    );

    await service.createGroup(uid, newGroup);

    setState(() {
      _isCreating = false;
      _nameController.clear();
    });
  }

  Future<void> _saveGroup(ContactGroup group) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final service = context.read<ConnectionsService>();

    // Update name if changed
    if (name != group.name) {
      await service.renameGroup(uid, group.id, name);
    }

    // Update appearance if changed
    if (_selectedColor.toARGB32() != group.colorValue ||
        _selectedIcon.codePoint != group.iconCodePoint) {
      await service.updateGroupAppearance(
        uid,
        group.id,
        colorValue: _selectedColor.toARGB32(),
        iconCodePoint: _selectedIcon.codePoint,
      );
    }

    setState(() {
      _editingGroupId = null;
      _nameController.clear();
    });
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context, ContactGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteConnectionGroupTitle),
        content: Text(
          AppLocalizations.of(context)!
              .deleteConnectionGroupMessage(group.name),
        ),
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
      await service.deleteGroup(uid, group.id);
    }
  }
}
