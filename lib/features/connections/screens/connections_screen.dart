import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/connections/models/person.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/connections/data/connections_service.dart';
import 'package:numer_app/features/connections/screens/add_person_sheet.dart';
import 'package:numer_app/features/connections/screens/person_details_screen.dart';
import 'package:numer_app/features/connections/screens/groups_management_sheet.dart';
import 'package:numer_app/features/connections/screens/people_calendar_screen.dart';
import 'package:numer_app/features/connections/widgets/person_card.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  String? _selectedGroupId;
  ConnectionsSortMode _sortMode = ConnectionsSortMode.recent;
  bool _initialized = false;
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  Future<void> _initializeService() async {
    if (_initialized) return;

    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final service = context.read<ConnectionsService>();
    await service.initialize(uid);

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthController>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse &&
                _fabVisible) {
              setState(() => _fabVisible = false);
            } else if (notification.direction == ScrollDirection.forward &&
                !_fabVisible) {
              setState(() => _fabVisible = true);
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(AppLocalizations.of(context)!.connectionsTabLabel),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.signInToViewConnections,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Consumer<ConnectionsService>(
        builder: (context, service, _) {
          if (!service.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredPeople = service.filterPeople(
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
            groupId: _selectedGroupId,
          );

          final sortedPeople = service.sortPeople(filteredPeople, _sortMode);
          final groups = service.groups;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(AppLocalizations.of(context)!.connectionsTabLabel),
                floating: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    tooltip: 'Calendar', // TODO: Localize
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PeopleCalendarScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_outlined),
                    tooltip: AppLocalizations.of(context)!.manageGroupsTitle,
                    onPressed: () => _openGroupsManagement(context),
                  ),
                ],
              ),

              // Search and Filter Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Input
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.searchConnectionsHint,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(128),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                      ),

                      const SizedBox(height: 12),

                      // Group Filter Chips
                      if (groups.isNotEmpty) ...[
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              // "All" chip
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(
                                    AppLocalizations.of(context)!.filterAll,
                                  ),
                                  selected: _selectedGroupId == null,
                                  onSelected: (_) {
                                    setState(() => _selectedGroupId = null);
                                  },
                                ),
                              ),
                              // Group chips
                              ...groups.map(
                                (group) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(group.name),
                                    selected: _selectedGroupId == group.id,
                                    selectedColor: group.color.withAlpha(51),
                                    avatar: _selectedGroupId == group.id
                                        ? null
                                        : CircleAvatar(
                                            backgroundColor: group.color
                                                .withAlpha(51),
                                            child: Icon(
                                              group.icon,
                                              size: 14,
                                              color: group.color,
                                            ),
                                          ),
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedGroupId =
                                            _selectedGroupId == group.id
                                            ? null
                                            : group.id;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Sort Selector
                      // Sort Selector (Cyclic Tap)
                      InkWell(
                        onTap: _cycleSortMode,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sort by:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getSortLabel(context, _sortMode),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.swap_vert,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // People List or Empty State
              if (sortedPeople.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, service.people.isEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final person = sortedPeople[index];
                      final personGroups = groups
                          .where((g) => person.groupIds.contains(g.id))
                          .toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PersonCard(
                          person: person,
                          groups: personGroups,
                          onTap: () => _openPersonDetails(context, person),
                          onCall:
                              person.phone != null && person.phone!.isNotEmpty
                              ? () => _makeCall(person.phone!)
                              : null,
                          onMessage:
                              person.phone != null && person.phone!.isNotEmpty
                              ? () => _sendMessage(person.phone!)
                              : null,
                          onEmail:
                              person.email != null && person.email!.isNotEmpty
                              ? () => _sendEmail(person.email!)
                              : null,
                        ),
                      );
                    }, childCount: sortedPeople.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutQuart,
        offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutQuart,
          opacity: _fabVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_fabVisible,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddPerson(context),
              icon: const Icon(Icons.person_add),
              label: Text(AppLocalizations.of(context)!.addPersonTitle),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isGlobalEmpty) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!isGlobalEmpty) {
      // No results for current filter
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha(179),
              ),
            ),
          ],
        ),
      );
    }

    // No connections at all
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noConnectionsPlaceholder,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start building your personal network by adding your first contact.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _openAddPerson(context),
              icon: const Icon(Icons.person_add),
              label: Text(AppLocalizations.of(context)!.addPersonTitle),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddPerson(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddPersonSheet(),
    );
  }

  void _openPersonDetails(BuildContext context, Person person) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailsScreen(personId: person.id),
      ),
    );
  }

  void _openGroupsManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const GroupsManagementSheet(),
    );
  }

  void _cycleSortMode() {
    setState(() {
      switch (_sortMode) {
        case ConnectionsSortMode.recent:
          _sortMode = ConnectionsSortMode.name;
          break;
        case ConnectionsSortMode.name:
          _sortMode = ConnectionsSortMode.priority;
          break;
        case ConnectionsSortMode.priority:
          _sortMode = ConnectionsSortMode.recent;
          break;
      }
    });
  }

  String _getSortLabel(BuildContext context, ConnectionsSortMode mode) {
    switch (mode) {
      case ConnectionsSortMode.recent:
        return AppLocalizations.of(context)!.sortByRecent;
      case ConnectionsSortMode.name:
        return AppLocalizations.of(context)!.sortByName;
      case ConnectionsSortMode.priority:
        return AppLocalizations.of(context)!.sortByPriority;
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
