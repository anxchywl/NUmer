import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/models/group.dart';
import 'package:numer_app/services/auth_service.dart';
import 'package:numer_app/services/group_service.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/widgets/user_profile_tile.dart';
import 'package:numer_app/widgets/app_toast.dart';

class ManageGroupScreen extends StatefulWidget {
  const ManageGroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<ManageGroupScreen> createState() => _ManageGroupScreenState();
}

class _ManageGroupScreenState extends State<ManageGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  GroupVisibility _visibility = GroupVisibility.public;
  bool _initialized = false;
  bool _saving = false;
  bool _deleting = false;
  bool _leaving = false;
  bool _codeLoaded = false;
  Stream<GroupMembership?>? _membershipStream;
  Stream<List<GroupMember>>? _membersStream;
  String? _lastGroupId;
  String? _lastUserId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) return;

    final service = context.watch<GroupService>();
    final auth = context.watch<AuthController>();
    final currentUserId = auth.currentUser?.uid;

    if (currentUserId != null &&
        (_lastUserId != currentUserId || _lastGroupId != widget.groupId)) {
      _lastUserId = currentUserId;
      _lastGroupId = widget.groupId;
      _membershipStream =
          service.watchMembershipForUser(currentUserId, widget.groupId);
      _membersStream = service.watchGroupMembers(widget.groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GroupService>();
    final auth = context.watch<AuthController>();
    final currentUserId = auth.currentUser?.uid;

    return Scaffold(
      body: StreamBuilder<Group?>(
        stream: service.watchGroup(widget.groupId),
        builder: (context, snapshot) {
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.unableToLoadGroup,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.checkConnection,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final group = snapshot.data;
          if (group == null) {
            return Center(
              child: Text(AppLocalizations.of(context)!.groupNotFound),
            );
          }
          if (!_initialized || _lastGroupId != widget.groupId || _lastUserId != currentUserId) {
            _visibility = group.visibility;
            _nameController.text = group.name;
            _descriptionController.text = group.description;
            _initialized = true;
            _lastGroupId = widget.groupId;
            _lastUserId = currentUserId;
            
            
            _membershipStream = service.watchMembershipForUser(currentUserId!, widget.groupId);
            _membersStream = service.watchGroupMembers(widget.groupId);

            if (_visibility == GroupVisibility.private) {
              _loadCode(service);
            }
          }

          if (currentUserId == null) {
            return Center(
              child: Text(AppLocalizations.of(context)!.signInToManage),
            );
          }

          return StreamBuilder<GroupMembership?>(
            key: ValueKey('membership_builder_${widget.groupId}_$currentUserId'),
            stream: _membershipStream,
            builder: (context, membershipSnap) {
              if (membershipSnap.hasError) {
                return Center(
                  child: Text(AppLocalizations.of(context)!.errorLoadingMemberships(membershipSnap.error.toString())),
                );
              }
              if (membershipSnap.connectionState == ConnectionState.waiting &&
                  !membershipSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final membership = membershipSnap.data;
              if (membership == null) {
                return Center(
                  child: Text(AppLocalizations.of(context)!.noLongerMember),
                );
              }

              final isAdmin = membership.isAdmin;
              final theme = Theme.of(context);

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: false,
                    floating: true,
                    title: Text(
                      AppLocalizations.of(context)!.manageGroup,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    actions: [
                      if (group.createdBy == currentUserId)
                        IconButton(
                          icon: _deleting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          tooltip: AppLocalizations.of(context)!.deleteGroup,
                          onPressed: _deleting ? null : () => _confirmDelete(service),
                        )
                      else
                        IconButton(
                          icon: _leaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.logout),
                          tooltip: AppLocalizations.of(context)!.leaveGroup,
                          onPressed: _leaving ? null : () => _leaveGroup(service),
                          color: Theme.of(context).colorScheme.error,
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.groupName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              enabled: isAdmin,
                              maxLength: 32,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\p{L}\p{N} ]', unicode: true),
                                ),
                              ],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(50),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: AppLocalizations.of(context)!.groupNameHint,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppLocalizations.of(context)!.description,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              enabled: isAdmin,
                              maxLength: 64,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\p{L}\p{N}\s]', unicode: true),
                                ),
                              ],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(50),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: AppLocalizations.of(context)!.descriptionHint,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.visibility,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<GroupVisibility>(
                              segments: [
                                ButtonSegment(
                                  value: GroupVisibility.public,
                                  label: Text(
                                    AppLocalizations.of(context)!.public,
                                    style: TextStyle(
                                      fontWeight: _visibility == GroupVisibility.public
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.public,
                                    color: _visibility == GroupVisibility.public
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                                ButtonSegment(
                                  value: GroupVisibility.private,
                                  label: Text(
                                    AppLocalizations.of(context)!.private,
                                    style: TextStyle(
                                      fontWeight: _visibility == GroupVisibility.private
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.lock,
                                    color: _visibility == GroupVisibility.private
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                              selected: <GroupVisibility>{_visibility},
                              onSelectionChanged: isAdmin
                                  ? (selection) {
                                      setState(() => _visibility = selection.first);
                                    }
                                  : null,
                              showSelectedIcon: false,
                            ),
                            if (_visibility == GroupVisibility.private) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _codeController,
                                enabled: isAdmin,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.groupCodeLabel,
                                  hintText: AppLocalizations.of(context)!.joinCodeHint,
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                ],
                                validator: (value) {
                                  if (_visibility == GroupVisibility.private && 
                                     (value == null || value.trim().isEmpty)) {
                                    return AppLocalizations.of(context)!.codeRequired;
                                  }
                                  return null;
                                },
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 4),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.codeJoinPrompt,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppLocalizations.of(context)!.friendJoinPrompt,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                            if (!isAdmin)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  AppLocalizations.of(context)!.onlyAdminVisibility,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: (_saving || !isAdmin)
                                  ? null
                                  : () => _saveChanges(
                                        service,
                                        canEditAdvanced: isAdmin,
                                      ),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _saving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveChanges,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.membersTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${group.memberCount})',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<List<GroupMember>>(
                              key: ValueKey('members_builder_${widget.groupId}'),
                              stream: _membersStream,
                              builder: (context, memberSnap) {
                                if (memberSnap.hasError) {
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 32,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppLocalizations.of(context)!.unableToLoadMembers,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppLocalizations.of(context)!.checkConnectionTryAgain,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                            onPressed: () => setState(() {}),
                                            icon: const Icon(Icons.refresh),
                                            label: Text(AppLocalizations.of(context)!.retry),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                if (memberSnap.connectionState ==
                                        ConnectionState.waiting &&
                                    !memberSnap.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final members = memberSnap.data ?? const <GroupMember>[];
                                if (members.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(AppLocalizations.of(context)!.noMembersYetLabel),
                                  );
                                }
                                return Column(
                                  children: members
                                      .map(
                                        (member) => Card(
                                          key: ValueKey(member.userId),
                                          child: UserProfileTile(
                                            userId: member.userId,
                                            role: member.role.label,
                                            showOnlyMajor: true,
                                            trailing: _buildMemberTrailing(
                                              member: member,
                                              currentUserId: currentUserId,
                                              service: service,
                                              canManageMembers: isAdmin,
                                              group: group,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                            if (!isAdmin)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _saveChanges(
    GroupService service, {
    required bool canEditAdvanced,
  }) async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      showAppMessage(context, 'Group name cannot be empty', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await service.updateGroup(
        groupId: widget.groupId,
        name: trimmedName,
        description: _descriptionController.text,
        
        visibility: canEditAdvanced ? _visibility : null,
        joinCode: (_visibility == GroupVisibility.private && canEditAdvanced) 
            ? _codeController.text.trim() 
            : null,
      );
      if (!mounted) return;
      showAppMessage(context, AppLocalizations.of(context)!.groupUpdated);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(context)!.failedToUpdateGroup(error.toString()),
        isError: true,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _confirmDelete(GroupService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteGroupTitle),
        content: Text(AppLocalizations.of(context)!.deleteGroupMessage),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      await service.deleteGroup(widget.groupId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          AppLocalizations.of(context)!.failedToDeleteGroup(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _leaveGroup(GroupService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leaveGroupTitle),
        content: Text(AppLocalizations.of(context)!.leaveGroupMessage),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.leave),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _leaving = true);

    try {
      await service.leaveGroup(widget.groupId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          AppLocalizations.of(context)!.failedToLeaveGroup(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _leaving = false);
      }
    }
  }



  Widget? _buildMemberTrailing({
    required GroupMember member,
    required String? currentUserId,
    required GroupService service,
    required bool canManageMembers,
    required Group group,
  }) {
    final isCreator = group.createdBy == currentUserId;
    final isSelf = member.userId == currentUserId;
    final isMemberAdmin = member.role == GroupRole.admin;

    
    if (isSelf) {
      String label;
      if (isCreator) {
        label = AppLocalizations.of(context)!.youOwner;
      } else if (isMemberAdmin) {
        label = AppLocalizations.of(context)!.youAdmin;
      } else {
        label = AppLocalizations.of(context)!.youMember;
      }
      return Chip(
        label: Text(label),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      );
    }

    if (member.userId == group.createdBy) {
      return Chip(label: Text(AppLocalizations.of(context)!.owner));
    }

    // If current user is Creator, they can promote/demote
    if (isCreator) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             if (isMemberAdmin)
               IconButton(
                 tooltip: AppLocalizations.of(context)!.demoteTooltip,
                 icon: const Icon(Icons.arrow_downward),
                 onPressed: () => _demoteMember(service, member.userId),
               )
             else
               IconButton(
                 tooltip: AppLocalizations.of(context)!.makeAdminTooltip,
                 icon: const Icon(Icons.arrow_upward),
                 onPressed: () => _promoteMember(service, member.userId),
               ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.removeMember,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeMember(service, member.userId),
              ),
          ],
        );
    }
    
    // If current user is Admin (but not creator)
    if (canManageMembers) {
       // Cannot remove the creator or other admins (depending on rules, but definitely not creator)
       // Usually admins cannot remove other admins. Let's stick to: Admins can remove MEMBERS.
       // But waiting, requirement says: "New admins... Cannot remove the creator admin"
       // It implies they CAN remove other members.
       // Verify if member is creator.
       if (member.userId == group.createdBy) {
         return Chip(label: Text(AppLocalizations.of(context)!.owner)); // Or just Admin
       }
       
       if (isMemberAdmin) {
          return Chip(label: Text(AppLocalizations.of(context)!.admin));
       }

       return IconButton(
          tooltip: AppLocalizations.of(context)!.removeMember,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _removeMember(service, member.userId),
        );
    }

    if (isMemberAdmin) {
      return Chip(label: Text(AppLocalizations.of(context)!.administrator));
    }
    
    return null;
  }

  Future<void> _promoteMember(GroupService service, String memberId) async {
      try {
        await service.promoteToAdmin(groupId: widget.groupId, memberId: memberId);
        if (!mounted) return;
        showAppMessage(context, AppLocalizations.of(context)!.memberPromoted);
      } catch (e) {
        if (!mounted) return;
        showAppMessage(context, AppLocalizations.of(context)!.failedToPromote, isError: true);
      }
  }

  Future<void> _demoteMember(GroupService service, String memberId) async {
      try {
        await service.demoteToMember(groupId: widget.groupId, memberId: memberId);
        if (!mounted) return;
        showAppMessage(context, AppLocalizations.of(context)!.adminDemoted);
      } catch (e) {
        if (!mounted) return;
        showAppMessage(context, AppLocalizations.of(context)!.failedToDemote, isError: true);
      }
  }

  Future<void> _removeMember(GroupService service, String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeMemberTitle),
        content: Text(AppLocalizations.of(context)!.removeMemberMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.removeMember(groupId: widget.groupId, memberId: memberId);
      if (!mounted) return;
      showAppMessage(context, AppLocalizations.of(context)!.memberRemoved);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(context)!.failedToRemoveMember(error.toString()),
        isError: true,
      );
    }
  }
  Future<void> _loadCode(GroupService service) async {
    if (_codeLoaded) return;
    _codeLoaded = true;
    try {
      final code = await service.getGroupJoinCode(widget.groupId);
      if (mounted && code != null) {
        setState(() => _codeController.text = code);
      }
    } catch (_) {
      
      
      
    }
  }
}
