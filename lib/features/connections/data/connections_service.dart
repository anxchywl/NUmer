import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:numer_app/features/connections/models/person.dart';
import 'package:numer_app/features/connections/models/contact_group.dart';

/// Service for managing Connections (personal CRM) data.
/// 
/// Design principles:
/// - Local-first: UI reads from local cache
/// - Minimal writes: Only sync on explicit save actions
/// - Batched updates: Single Firestore write per save operation
class ConnectionsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Local cache
  List<Person> _peopleCache = [];
  List<ContactGroup> _groupsCache = [];
  bool _isLoaded = false;
  
  // Getters for cached data
  List<Person> get people => List.unmodifiable(_peopleCache.where((p) => !p.deleted));
  List<ContactGroup> get groups => List.unmodifiable(_groupsCache.where((g) => !g.deleted));
  bool get isLoaded => _isLoaded;
  
  // Stream controllers for reactive updates
  final _peopleController = StreamController<List<Person>>.broadcast();
  final _groupsController = StreamController<List<ContactGroup>>.broadcast();
  
  Stream<List<Person>> get peopleStream => _peopleController.stream;
  Stream<List<ContactGroup>> get groupsStream => _groupsController.stream;
  
  // Collection references
  CollectionReference<Map<String, dynamic>> _connectionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('connections');
      
  CollectionReference<Map<String, dynamic>> _groupsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('connectionGroups');

  /// Initialize the service and load data from Firestore
  Future<void> initialize(String uid) async {
    if (_isLoaded) return;
    
    await Future.wait([
      _loadPeople(uid),
      _loadGroups(uid),
    ]);
    
    _isLoaded = true;
    notifyListeners();
  }

  /// Load people from Firestore into cache
  Future<void> _loadPeople(String uid) async {
    try {
      final snapshot = await _connectionsRef(uid)
          .where('d', isNotEqualTo: true)
          .orderBy('d')
          .orderBy('so')
          .get();
      
      _peopleCache = snapshot.docs
          .map((doc) => Person.fromFirestore(doc))
          .toList();
      
      _peopleController.add(people);
    } catch (e) {
      debugPrint('ConnectionsService: Error loading people: $e');
      _peopleCache = [];
    }
  }

  /// Load groups from Firestore into cache
  Future<void> _loadGroups(String uid) async {
    try {
      final snapshot = await _groupsRef(uid)
          .where('d', isNotEqualTo: true)
          .orderBy('d')
          .orderBy('n')
          .get();
      
      _groupsCache = snapshot.docs
          .map((doc) => ContactGroup.fromFirestore(doc))
          .toList();
      
      // Ensure default groups exist
      await _ensureDefaultGroups(uid);
      
      _groupsController.add(groups);
    } catch (e) {
      debugPrint('ConnectionsService: Error loading groups: $e');
      _groupsCache = [];
      // Still try to create default groups
      await _ensureDefaultGroups(uid);
    }
  }

  /// Ensure default groups exist for the user
  Future<void> _ensureDefaultGroups(String uid) async {
    final defaultGroups = ContactGroup.defaultGroups;
    bool added = false;
    
    for (final defaultGroup in defaultGroups) {
      final exists = _groupsCache.any((g) => g.id == defaultGroup.id);
      if (!exists) {
        await _groupsRef(uid).doc(defaultGroup.id).set(defaultGroup.toFirestore());
        _groupsCache.add(defaultGroup);
        added = true;
      }
    }
    
    if (added) {
      _groupsController.add(groups);
      notifyListeners();
    }
  }

  /// Refresh all data from Firestore
  Future<void> refresh(String uid) async {
    _isLoaded = false;
    await initialize(uid);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PEOPLE CRUD
  // ─────────────────────────────────────────────────────────────────────────

  /// Add a new person
  Future<void> addPerson(String uid, Person person) async {
    // Set sort order if not specified
    final sortOrder = person.sortOrder == 0 
        ? (_peopleCache.isEmpty ? 0 : _peopleCache.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1)
        : person.sortOrder;
    
    final updatedPerson = person.copyWith(
      sortOrder: sortOrder,
      updatedAt: DateTime.now(),
    );
    
    // Write to Firestore
    await _connectionsRef(uid).doc(person.id).set(updatedPerson.toFirestore());
    
    // Update local cache
    _peopleCache.add(updatedPerson);
    _peopleController.add(people);
    notifyListeners();
  }

  /// Update an existing person
  Future<void> updatePerson(String uid, Person person) async {
    final updatedPerson = person.copyWith(updatedAt: DateTime.now());
    
    // Write to Firestore
    await _connectionsRef(uid).doc(person.id).set(updatedPerson.toFirestore());
    
    // Update local cache
    final index = _peopleCache.indexWhere((p) => p.id == person.id);
    if (index >= 0) {
      _peopleCache[index] = updatedPerson;
    } else {
      _peopleCache.add(updatedPerson);
    }
    
    _peopleController.add(people);
    notifyListeners();
  }

  /// Delete a person (soft delete)
  Future<void> deletePerson(String uid, String personId) async {
    final index = _peopleCache.indexWhere((p) => p.id == personId);
    if (index < 0) return;
    
    final deletedPerson = _peopleCache[index].copyWith(
      deleted: true,
      updatedAt: DateTime.now(),
    );
    
    // Write to Firestore
    await _connectionsRef(uid).doc(personId).update({
      'd': true,
      'ua': Timestamp.fromDate(deletedPerson.updatedAt),
    });
    
    // Update local cache
    _peopleCache[index] = deletedPerson;
    _peopleController.add(people);
    notifyListeners();
  }

  /// Get a person by ID from cache
  Person? getPersonById(String personId) {
    try {
      return _peopleCache.firstWhere((p) => p.id == personId && !p.deleted);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUPS CRUD
  // ─────────────────────────────────────────────────────────────────────────

  /// Create a new group
  Future<void> createGroup(String uid, ContactGroup group) async {
    // Write to Firestore
    await _groupsRef(uid).doc(group.id).set(group.toFirestore());
    
    // Update local cache
    _groupsCache.add(group);
    _groupsController.add(groups);
    notifyListeners();
  }

  /// Rename a group
  Future<void> renameGroup(String uid, String groupId, String newName) async {
    final index = _groupsCache.indexWhere((g) => g.id == groupId);
    if (index < 0) return;
    
    final updatedGroup = _groupsCache[index].copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    
    // Write to Firestore
    await _groupsRef(uid).doc(groupId).update({
      'n': newName,
      'ua': Timestamp.fromDate(updatedGroup.updatedAt),
    });
    
    // Update local cache
    _groupsCache[index] = updatedGroup;
    _groupsController.add(groups);
    notifyListeners();
  }

  /// Update a group's color and icon
  Future<void> updateGroupAppearance(String uid, String groupId, {int? colorValue, int? iconCodePoint}) async {
    final index = _groupsCache.indexWhere((g) => g.id == groupId);
    if (index < 0) return;
    
    final updatedGroup = _groupsCache[index].copyWith(
      colorValue: colorValue ?? _groupsCache[index].colorValue,
      iconCodePoint: iconCodePoint ?? _groupsCache[index].iconCodePoint,
      updatedAt: DateTime.now(),
    );
    
    final updates = <String, dynamic>{
      'ua': Timestamp.fromDate(updatedGroup.updatedAt),
    };
    if (colorValue != null) updates['cl'] = colorValue;
    if (iconCodePoint != null) updates['ic'] = iconCodePoint;
    
    // Write to Firestore
    await _groupsRef(uid).doc(groupId).update(updates);
    
    // Update local cache
    _groupsCache[index] = updatedGroup;
    _groupsController.add(groups);
    notifyListeners();
  }

  /// Delete a group (soft delete)
  Future<void> deleteGroup(String uid, String groupId) async {
    final index = _groupsCache.indexWhere((g) => g.id == groupId);
    if (index < 0) return;
    
    // Don't allow deleting default groups
    if (_groupsCache[index].isDefault) return;
    
    final deletedGroup = _groupsCache[index].copyWith(
      deleted: true,
      updatedAt: DateTime.now(),
    );
    
    // Write to Firestore
    await _groupsRef(uid).doc(groupId).update({
      'd': true,
      'ua': Timestamp.fromDate(deletedGroup.updatedAt),
    });
    
    // Remove group from all people
    for (var i = 0; i < _peopleCache.length; i++) {
      final person = _peopleCache[i];
      if (person.groupIds.contains(groupId)) {
        final updatedGroupIds = List<String>.from(person.groupIds)..remove(groupId);
        final updatedPerson = person.copyWith(
          groupIds: updatedGroupIds,
          updatedAt: DateTime.now(),
        );
        
        await _connectionsRef(uid).doc(person.id).update({
          'g': updatedGroupIds,
          'ua': Timestamp.fromDate(updatedPerson.updatedAt),
        });
        
        _peopleCache[i] = updatedPerson;
      }
    }
    
    // Update local cache
    _groupsCache[index] = deletedGroup;
    _groupsController.add(groups);
    _peopleController.add(people);
    notifyListeners();
  }

  /// Get a group by ID from cache
  ContactGroup? getGroupById(String groupId) {
    try {
      return _groupsCache.firstWhere((g) => g.id == groupId && !g.deleted);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERACTION LOG
  // ─────────────────────────────────────────────────────────────────────────

  /// Add an interaction log entry
  Future<void> addInteraction(String uid, String personId, InteractionEntry entry) async {
    final index = _peopleCache.indexWhere((p) => p.id == personId);
    if (index < 0) return;
    
    final person = _peopleCache[index];
    final updatedLog = [...person.interactionLog, entry];
    final updatedPerson = person.copyWith(
      interactionLog: updatedLog,
      updatedAt: DateTime.now(),
    );
    
    // Write to Firestore
    await _connectionsRef(uid).doc(personId).update({
      'il': updatedLog.map((e) => e.toMap()).toList(),
      'ua': Timestamp.fromDate(updatedPerson.updatedAt),
    });
    
    // Update local cache
    _peopleCache[index] = updatedPerson;
    _peopleController.add(people);
    notifyListeners();
  }

  /// Mark a person as contacted today
  Future<void> markContactedToday(String uid, String personId, {String? note}) async {
    final index = _peopleCache.indexWhere((p) => p.id == personId);
    if (index < 0) return;
    
    final now = DateTime.now();
    final person = _peopleCache[index];
    
    // Create interaction log entry
    final entry = InteractionEntry(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      note: note ?? 'Contacted',
      createdAt: now,
    );
    
    final updatedLog = [...person.interactionLog, entry];
    final updatedPerson = person.copyWith(
      lastContactedAt: now,
      interactionLog: updatedLog,
      updatedAt: now,
    );
    
    // Write to Firestore
    await _connectionsRef(uid).doc(personId).update({
      'lc': Timestamp.fromDate(now),
      'il': updatedLog.map((e) => e.toMap()).toList(),
      'ua': Timestamp.fromDate(now),
    });
    
    // Update local cache
    _peopleCache[index] = updatedPerson;
    _peopleController.add(people);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTERING & SORTING
  // ─────────────────────────────────────────────────────────────────────────

  /// Filter people by search query (local only, no DB calls)
  List<Person> filterPeople({
    String? searchQuery,
    String? groupId,
    bool? needsFollowUp,
    bool? recentlyContacted,
  }) {
    var result = people;
    
    // Search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.tags.any((t) => t.toLowerCase().contains(query)) ||
            (p.notes?.toLowerCase().contains(query) ?? false) ||
            (p.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Group filter
    if (groupId != null) {
      result = result.where((p) => p.groupIds.contains(groupId)).toList();
    }
    
    // Needs follow-up filter
    if (needsFollowUp == true) {
      result = result.where((p) => p.needsFollowUp).toList();
    }
    
    // Recently contacted filter
    if (recentlyContacted == true) {
      result = result.where((p) => p.recentlyContacted).toList();
    }
    
    return result;
  }

  /// Sort people by different criteria
  List<Person> sortPeople(List<Person> people, ConnectionsSortMode mode) {
    final sorted = List<Person>.from(people);
    
    switch (mode) {
      case ConnectionsSortMode.recent:
        sorted.sort((a, b) {
          final aDate = a.lastContactedAt ?? DateTime(1970);
          final bDate = b.lastContactedAt ?? DateTime(1970);
          return bDate.compareTo(aDate); // Most recent first
        });
        break;
      case ConnectionsSortMode.name:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ConnectionsSortMode.priority:
        sorted.sort((a, b) {
          // Priority: needs follow-up first, then by last contacted
          if (a.needsFollowUp && !b.needsFollowUp) return -1;
          if (!a.needsFollowUp && b.needsFollowUp) return 1;
          final aDate = a.lastContactedAt ?? DateTime(1970);
          final bDate = b.lastContactedAt ?? DateTime(1970);
          return aDate.compareTo(bDate); // Oldest first for priority
        });
        break;
    }
    
    return sorted;
  }

  /// Get people who need follow-up (not contacted in 30+ days)
  List<Person> get peopleNeedingFollowUp {
    return people.where((p) => p.needsFollowUp).toList();
  }

  /// Get recently contacted people (within last 7 days)
  List<Person> get recentlyContactedPeople {
    return people.where((p) => p.recentlyContacted).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Clear local cache (call on sign out)
  void clear() {
    _peopleCache = [];
    _groupsCache = [];
    _isLoaded = false;
    _peopleController.add([]);
    _groupsController.add([]);
    notifyListeners();
  }

  @override
  void dispose() {
    _peopleController.close();
    _groupsController.close();
    super.dispose();
  }
}

/// Sort modes for connections list
enum ConnectionsSortMode {
  recent,
  name,
  priority,
}
