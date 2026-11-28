import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/connections/models/person.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/connections/data/connections_service.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import '../widgets/person_extras.dart';
import '../widgets/person_text_field.dart';

class AddPersonSheet extends StatefulWidget {
  final Person? person; // For editing existing person

  const AddPersonSheet({super.key, this.person});

  @override
  State<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _focus = NumerSheetFocusMode();

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
    _tagsController = TextEditingController(
      text: person?.tags.join(', ') ?? '',
    );
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
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    final chrome = _focus.hidesChrome;
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
            NumerFocusFold(hidden: chrome, child: _header(context)),
            Flexible(
              // while typing the sheet is only as tall as the field and done
              fit: chrome ? FlexFit.loose : FlexFit.tight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _fields(context),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SheetDoneActions(
                focus: _focus,
                actions: _saveButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? l10n.editPersonTitle : l10n.addPersonTitle,
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

  List<Widget> _fields(BuildContext context) {
    final chrome = _focus.hidesChrome;
    final gap = NumerFocusGap(hidden: chrome, height: 20);
    return [
      _nameField(context),
      gap,
      NumerFocusFold(hidden: chrome, child: _groupPicker(context)),
      gap,
      _tagsField(context),
      NumerFocusFold(hidden: chrome, child: _tagsHelper(context)),
      gap,
      _phoneField(context),
      gap,
      _emailField(context),
      gap,
      _notesField(context),
      gap,
      NumerFocusFold(
        hidden: chrome,
        child: PersonContactOptions(
          lastContactedAt: _lastContactedAt,
          remind: _remindToReachOut,
          onPickDate: () => _selectDate(context),
          onClearDate: () => setState(() => _lastContactedAt = null),
        ),
      ),
      NumerFocusGap(hidden: chrome, height: 32),
    ];
  }

  Widget _groupPicker(BuildContext context) {
    return PersonGroupPicker(
      groups: context.watch<ConnectionsService>().groups,
      selectedIds: _selectedGroupIds,
      onChanged: (id, selected) => setState(() {
        if (selected) {
          _selectedGroupIds.add(id);
        } else {
          _selectedGroupIds.remove(id);
        }
      }),
    );
  }

  Widget _tagsHelper(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Separate tags with commas',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _nameField(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PersonTextField(
      focus: _focus,
      id: 'name',
      next: 'tags',
      controller: _nameController,
      label: l10n.personNameLabel,
      hint: l10n.personNameHint,
      icon: Icons.person_outline,
      maxLength: 64,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return l10n.nameRequired;
        return null;
      },
    );
  }

  Widget _tagsField(BuildContext context) {
    return PersonTextField(
      focus: _focus,
      id: 'tags',
      next: 'phone',
      controller: _tagsController,
      label: AppLocalizations.of(context)!.tagsLabel,
      hint: 'e.g., mentor, networking, coffee',
      icon: Icons.tag,
      maxLength: 128,
    );
  }

  Widget _phoneField(BuildContext context) {
    return PersonTextField(
      focus: _focus,
      id: 'phone',
      next: 'email',
      controller: _phoneController,
      label: AppLocalizations.of(context)!.phoneLabel,
      hint: 'Enter phone number',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      maxLength: 20,
      extraFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-+().]')),
      ],
    );
  }

  Widget _emailField(BuildContext context) {
    return PersonTextField(
      focus: _focus,
      id: 'email',
      next: 'notes',
      controller: _emailController,
      label: AppLocalizations.of(context)!.emailLabel,
      hint: 'Enter email address',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      maxLength: 128,
    );
  }

  Widget _notesField(BuildContext context) {
    return PersonTextField(
      focus: _focus,
      id: 'notes',
      controller: _notesController,
      label: AppLocalizations.of(context)!.notesLabel,
      hint: 'Add any notes about this person...',
      icon: Icons.notes_outlined,
      maxLines: 3,
      maxLength: 500,
    );
  }

  Widget _saveButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton(
      onPressed: _isSaving ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: NumerButtonChild(
        label: _isEditing ? l10n.saveChanges : l10n.addPersonTitle,
        loading: _isSaving,
        loadingHint: l10n.loadingHint,
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
          ? tagsText
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList()
          : <String>[];

      if (_isEditing) {
        // Update existing person
        final updatedPerson = widget.person!.copyWith(
          name: _nameController.text.trim(),
          groupIds: _selectedGroupIds.toList(),
          tags: tags,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
        showAppMessage(
          context,
          AppLocalizations.of(context)!.errorSaving(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
