import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/features/groups/models/group.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/groups/data/group_service.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/groups/widgets/group_leaderboard.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/tip_icon.dart';
import 'package:numer_app/features/groups/screens/create_group_screen.dart';
import 'package:numer_app/features/groups/screens/manage_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final Set<String> _joining = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(AppLocalizations.of(context)!.groups),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(AppLocalizations.of(context)!.signInPrompt),
              ),
            ),
          ],
        ),
      );
    }

    final groupService = context.read<GroupService>();

    return Scaffold(
      body: StreamBuilder<List<GroupMembership>>(
        stream: groupService.watchUserMemberships(currentUser.uid),
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

          final memberships = membershipSnap.data ?? const <GroupMembership>[];
          final hasMemberships = memberships.isNotEmpty;
          final showSearchSection = !hasMemberships;
          final groupsStream = showSearchSection
              ? (_searchQuery.isEmpty
                  ? groupService.watchPublicGroups()
                  : groupService.searchGroups(_searchQuery))
              : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  hasMemberships
                      ? AppLocalizations.of(context)!.yourGroup
                      : AppLocalizations.of(context)!.groups,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                actions: [
                  if (hasMemberships)
                    TipIcon(
                      title: AppLocalizations.of(context)!.tip,
                      message: AppLocalizations.of(context)!.leaderboardHintMessage,
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: _MembershipSection(
                  memberships: memberships,
                  currentUserId: currentUser.uid,
                  onCreateGroup: () => _openCreateGroup(context),
                  onJoinPrivate: () => _showJoinPrivateDialog(),
                ),
              ),
              if (showSearchSection) ...[
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.findPublicGroupHint,
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _searchQuery.isEmpty ? AppLocalizations.of(context)!.publicGroups : AppLocalizations.of(context)!.searchResults,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (groupsStream != null)
                  StreamBuilder<List<Group>>(
                    stream: groupsStream,
                    builder: (context, groupSnap) {
                      if (groupSnap.hasError) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(AppLocalizations.of(context)!.errorLoadingGroups(groupSnap.error.toString())),
                            ),
                          ),
                        );
                      }

                      final groups = groupSnap.data ?? const <Group>[];
                      if (groups.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.noSearchResults,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final group = groups[index];
                            final isJoined = memberships.any((m) => m.groupId == group.id);
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: _GroupCard(
                                group: group,
                                isJoining: _joining.contains(group.id),
                                onJoin: isJoined
                                    ? null 
                                    : () => _handleJoinGroup(group),
                              ),
                            );
                          },
                          childCount: groups.length,
                        ),
                      );
                    },
                  ),
              ],
              SliverPadding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinPrivateDialog() {
    showDialog(
      context: context,
      builder: (_) => _JoinPrivateGroupDialog(
        groupName: AppLocalizations.of(context)!.private,
        onJoin: (code) {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
        }, 
      ),
    );
  }

  Future<void> _handleJoinGroup(Group group) async {
    if (_joining.contains(group.id)) return;

    if (group.isPublic) {
      
      setState(() => _joining.add(group.id));
      try {
        await context.read<GroupService>().joinGroup(group.id);
        if (!mounted) return;
        showAppMessage(context, AppLocalizations.of(context)!.joinedSuccessfully);
      } catch (error) {
        if (!mounted) return;
        showAppMessage(
          context,
          AppLocalizations.of(context)!.joinError(error.toString()),
          isError: true,
        );
      } finally {
        if (mounted) {
          setState(() => _joining.remove(group.id));
        }
      }
    } else {
      
      await showDialog(
        context: context,
        builder: (_) => _JoinPrivateGroupDialog(
          groupName: group.name,
          onJoin: (code) => _joinPrivateGroup(group.id, code),
        ),
      );
    }
  }

  Future<void> _joinPrivateGroup(String groupId, String code) async {
    setState(() => _joining.add(groupId));
    try {
      await context.read<GroupService>().joinPrivateGroup(groupId, code);
      if (!mounted) return;
      showAppMessage(context, AppLocalizations.of(context)!.joinedPrivateSuccessfully);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(context)!.joinError(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _joining.remove(groupId));
      }
    }
  }

  void _openCreateGroup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }


}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    this.isJoining = false,
    this.onJoin,
  });

  final Group group;
  final bool isJoining;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  group.isPublic ? Icons.public : Icons.lock,
                  color: colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              group.description.isEmpty
                  ? AppLocalizations.of(context)!.noDescription
                  : group.description,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!
                              .membersCount(group.memberCount),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onJoin != null) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: isJoining ? null : onJoin,
                    child: isJoining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context)!.joinGroup),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipSection extends StatelessWidget {
  const _MembershipSection({
    required this.memberships,
    required this.currentUserId,
    required this.onCreateGroup,
    required this.onJoinPrivate,
  });

  final List<GroupMembership> memberships;
  final String currentUserId;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinPrivate;

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty) {
      return _NoGroupView(
        onCreateGroup: onCreateGroup,
        onJoinPrivate: onJoinPrivate,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...memberships.map(
          (membership) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MembershipCard(
                  membership: membership,
                  currentUserId: currentUserId,
                ),
              ),
              const SizedBox(height: 24),
              GroupLeaderboard(
                groupId: membership.groupId,
                currentUserId: currentUserId,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoGroupView extends StatelessWidget {
  const _NoGroupView({
    required this.onCreateGroup,
    required this.onJoinPrivate,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinPrivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.findStudyGroup,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.joinCommunityPrompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateGroup,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(AppLocalizations.of(context)!.createGroup),
            ),
          ),
          
          
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    required this.currentUserId,
  });

  final GroupMembership membership;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final service = context.read<GroupService>();
    return StreamBuilder<Group?>(
      stream: service.watchGroup(membership.groupId),
      builder: (context, snapshot) {
        final group = snapshot.data;
        if (group == null) {
          return const SizedBox.shrink();
        }

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(
            group.isPublic ? Icons.groups_outlined : Icons.lock_outline,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            group.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            group.createdBy == currentUserId 
              ? AppLocalizations.of(context)!.owner 
              : (membership.isAdmin ? AppLocalizations.of(context)!.administrator : AppLocalizations.of(context)!.memberLabel),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.groupSettings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageGroupScreen(groupId: group.id),
                ),
              );
            },
          ),
        ),
      );
      },
    );
  }
}

class _JoinPrivateGroupDialog extends StatefulWidget {
  const _JoinPrivateGroupDialog({
    required this.groupName,
    required this.onJoin,
  });

  final String groupName;
  final ValueChanged<String> onJoin;

  @override
  State<_JoinPrivateGroupDialog> createState() => _JoinPrivateGroupDialogState();
}

class _JoinPrivateGroupDialogState extends State<_JoinPrivateGroupDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;

  void _validate() {
    final text = _controller.text;
    final valid = text.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.joinGroupDialogTitle(widget.groupName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.joinGroupDialogMessage),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.groupCodeLabel,
              border: const OutlineInputBorder(),
              hintText: AppLocalizations.of(context)!.joinCodeHint,
            ),
            inputFormatters: [
               FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            onChanged: (_) => _validate(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: _isValid
              ? () {
                  Navigator.of(context).pop();
                  widget.onJoin(_controller.text);
                }
              : null,
          child: Text(AppLocalizations.of(context)!.joinGroup),
        ),
      ],
    );
  }
}
