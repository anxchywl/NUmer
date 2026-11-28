import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/connections/models/contact_group.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/connections/data/connections_service.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import '../widgets/group_editor_card.dart';
import '../widgets/group_style_pickers.dart';

class GroupsManagementSheet extends StatefulWidget {
  const GroupsManagementSheet({super.key});

  @override
  State<GroupsManagementSheet> createState() => _GroupsManagementSheetState();
}

class _GroupsManagementSheetState extends State<GroupsManagementSheet> {
  final _focus = NumerSheetFocusMode();
  bool _isCreating = false;
  String? _editingGroupId;

  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  IconData _selectedIcon = Icons.group;

  @override
  void dispose() {
    _nameController.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    final groups = context.watch<ConnectionsService>().groups;
    final chrome = _focus.hidesChrome;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumerFocusFold(hidden: chrome, child: _header(context)),
            Flexible(
              // while typing the sheet is only as tall as the field and save
              fit: chrome ? FlexFit.loose : FlexFit.tight,
              child: ListView(
                shrinkWrap: chrome,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...groups.map(
                    (group) => NumerFocusFold(
                      hidden: chrome && _editingGroupId != group.id,
                      child: _buildGroupTile(context, group),
                    ),
                  ),
                  if (_isCreating)
                    _buildCreateForm(context)
                  else
                    NumerFocusFold(hidden: chrome, child: _createTile(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.manageGroupsTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
      ],
    );
  }

  Widget _createTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.add, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(AppLocalizations.of(context)!.createGroup),
      onTap: () {
        setState(() {
          _isCreating = true;
          _editingGroupId = null;
          _nameController.clear();
          _selectedColor = groupColorChoices.first;
          _selectedIcon = groupIconChoices.first;
        });
      },
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
        child: Icon(group.icon, color: group.color, size: 20),
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
                      Text(
                        AppLocalizations.of(context)!.delete,
                        style: TextStyle(color: Colors.red),
                      ),
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
    final l10n = AppLocalizations.of(context)!;
    return _buildEditor(
      title: l10n.newGroup,
      hint: l10n.groupNameHint,
      onCancel: () => setState(() {
        _isCreating = false;
        _nameController.clear();
      }),
      onSave: _createGroup,
    );
  }

  Widget _buildEditForm(BuildContext context, ContactGroup group) {
    return _buildEditor(
      title: AppLocalizations.of(context)!.editGroup,
      onCancel: () => setState(() {
        _editingGroupId = null;
        _nameController.clear();
      }),
      onSave: () => _saveGroup(group),
    );
  }

  Widget _buildEditor({
    required String title,
    String? hint,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return GroupEditorCard(
      focus: _focus,
      title: title,
      hint: hint,
      controller: _nameController,
      color: _selectedColor,
      icon: _selectedIcon,
      onColor: (color) => setState(() => _selectedColor = color),
      onIcon: (icon) => setState(() => _selectedIcon = icon),
      onCancel: onCancel,
      onSave: onSave,
    );
  }

  Future<void> _createGroup() async {
    _focus.release();
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
    _focus.release();
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
    BuildContext context,
    ContactGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteConnectionGroupTitle),
        content: Text(
          AppLocalizations.of(
            context,
          )!.deleteConnectionGroupMessage(group.name),
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
