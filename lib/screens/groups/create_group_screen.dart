import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../widgets/app_toast.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  GroupVisibility _visibility = GroupVisibility.public;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Group'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Start a Community',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a space for your friends or classmates to study together.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionLabel(context, 'Group Details'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                prefixIcon: const Icon(Icons.group_outlined),
                filled: true,
                focusColor: colorScheme.primary,
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
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                LengthLimitingTextInputFormatter(32),
                FilteringTextInputFormatter.allow(
                  RegExp(r'[\p{L}\p{N} ]', unicode: true),
                ),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name for your group';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'What is this group about?',
                filled: true,
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
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(63),
                FilteringTextInputFormatter.allow(
                  RegExp(r'[\p{L}\p{N}\s]', unicode: true),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionLabel(context, 'Privacy Settings'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _VisibilityCard(
                    title: 'Public',
                    icon: Icons.public,
                    isSelected: _visibility == GroupVisibility.public,
                    onTap: () => setState(() => _visibility = GroupVisibility.public),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VisibilityCard(
                    title: 'Private',
                    icon: Icons.lock,
                    isSelected: _visibility == GroupVisibility.private,
                    onTap: () => setState(() => _visibility = GroupVisibility.private),
                  ),
                ),
              ],
            ),
            if (_visibility == GroupVisibility.private) ...[
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Access Code',
                  prefixIcon: const Icon(Icons.key),
                  helperText: 'Members will need this code to join.',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                validator: (value) {
                  if (_visibility == GroupVisibility.private) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Code is required for private groups';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                      return 'Only letters and numbers allowed';
                    }
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Community',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
          ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    
    if (_visibility == GroupVisibility.private && _codeController.text.trim().length < 4) {
      showAppMessage(
        context,
        'Access code must be at least 4 characters',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final service = context.read<GroupService>();
    try {
      await service.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        joinCode: _visibility == GroupVisibility.private ? _codeController.text.trim() : null,
      );
      if (!mounted) return;
      showAppMessage(context, 'Group created successfully!');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        'Failed to create group: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final borderColor = isSelected ? colorScheme.primary : colorScheme.outlineVariant;
    final backgroundColor = isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent;
    final iconColor = isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final textColor = isSelected ? colorScheme.primary : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
