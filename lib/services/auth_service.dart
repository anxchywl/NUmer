import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications.dart';
import 'storage.dart';
import 'sync_service.dart';
import 'user_storage.dart';
import '../data/local/local_database.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

class AuthController extends ChangeNotifier {
  AuthController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _auth.authStateChanges().listen(_handleAuthState);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  SyncService? _syncService;
  late final StreamSubscription<User?> _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<String>? _fcmTokenSub;
  StreamSubscription<RemoteMessage>? _fcmMessageSub;

  User? _currentUser;
  Map<String, dynamic>? _profileData;
  bool _profileReady = false;
  bool _isBusy = false;
  bool _initialized = false;
  Future<void>? _initializingUser;
  bool _syncReady = false;
  bool _forcedLoggedOut = false;
  bool _requiresEmailVerification = false;
  bool _pendingAccountDeletedMessage = false;
  bool _isBootstrapping = false;
  bool _isSigningOut = false;
  int _lastResetRequestMs = 0;

  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profileData;
  bool get isProfileReady => _profileReady;
  bool get isBusy => _isBusy;
  bool get isInitialized => _initialized;
  bool get emailVerified => _currentUser?.emailVerified ?? false;
  bool get isSyncReady => _currentUser == null || _syncReady;
  bool get wasForcedLoggedOut => _forcedLoggedOut;
  bool get requiresEmailVerification => _requiresEmailVerification;
  bool get isBootstrapping => _isBootstrapping;
  bool get isSigningOut => _isSigningOut;

  bool consumeAccountDeletedMessage() {
    if (!_pendingAccountDeletedMessage) return false;
    _pendingAccountDeletedMessage = false;
    return true;
  }

  void attachSyncService(SyncService service) {
    _syncService = service;
  }

  void clearForcedLogoutFlag() {
    if (_forcedLoggedOut) {
      _forcedLoggedOut = false;
      notifyListeners();
    }
  }

  Future<String?> sendEmailVerification() async {
    final user = _currentUser;
    if (user == null) {
      return 'Not logged in';
    }
    if (user.emailVerified) {
      return 'Email already verified';
    }

    try {
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageForAuthCode(e.code);
    } catch (_) {
      return 'Failed to send verification email. Please try again later.';
    }
  }

  void _handleAuthState(User? user) {
    final previousUid = _currentUser?.uid;
    _currentUser = user;
    _initialized = true;

    if (user == null) {
      _requiresEmailVerification = false;
      lastPreparationError = null;
      _syncReady = false;
      _initializingUser = null;
      _profileData = null;
      _profileReady = false;
      _isBootstrapping = false;
      _isSigningOut = false;
      _fcmTokenSub?.cancel();
      _fcmMessageSub?.cancel();
      UserStorage.setCurrentUser(null);
      _performSignOutCleanup(previousUid);
      notifyListeners();
      return;
    }

    if (!user.emailVerified) {
      _requiresEmailVerification = true;
      _syncService?.stop();
      _syncReady = false;
      _initializingUser = null;
      _profileData = null;
      _profileReady = false;
      _isBootstrapping = false;
      UserStorage.setCurrentUser(null);
      notifyListeners();
      return;
    }

    _requiresEmailVerification = false;
    _isSigningOut = false;
    unawaited(_ensureProfileDocument(user));
    unawaited(_upsertEmailIndex(user.email, user.uid));
    unawaited(_registerPushToken(user));
    _listenToProfile(user);
    lastPreparationError = null;
    _forcedLoggedOut = false;
    UserStorage.setCurrentUser(user.uid);
    _syncReady = false;

    final future = _prepareUser(user);
    _initializingUser = future;
    unawaited(future.then((_) {
      if (identical(_initializingUser, future)) {
        _syncReady = true;
        _initializingUser = null;
        notifyListeners();
      }
    }).catchError((error, stack) {
      if (kDebugMode) {
        print('Failed to prepare user data: $error\n$stack');
      }
      lastPreparationError = error.toString();
      notifyListeners();
    }));
    notifyListeners();
  }

  String? lastPreparationError;

  Future<void> _performSignOutCleanup(String? previousUid) async {
    // Push any pending changes to Firebase before logout
    try {
      await _syncService?.pushDirty();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to push dirty data on logout: $e');
      }
    }

    await _syncService?.stop();
    if (previousUid != null) {
      await _clearLocalUserData(previousUid);
    } else {
      await Storage.closeForSignOut();
    }
  }

  Future<void> _prepareUser(User user) async {
    final deviceId = await _ensureDeviceId();
    await Storage.configureForUser(user.uid);
    final hasLocalCache = LocalDatabase.instance.hasBootstrapCache();
    final needsBootstrap = !hasLocalCache;
    final existingBootstrapVersion = await Storage.getBootstrapVersionFlag();

    // Seed profile + sync readiness from local cache for fast return-user startup
    final localProfile = LocalDatabase.instance.userDocOrNull;
    if (localProfile != null) {
      _profileData ??= {
        'profileName': localProfile.profileName,
        'displayName': localProfile.profileName,
        'profileComplete': localProfile.profileComplete,
        'onboardingCompleted': localProfile.onboardingCompleted,
      };
      _profileReady = true;
    }
    if (hasLocalCache) {
      _syncReady = true;
    }
    _isBootstrapping = needsBootstrap;
    notifyListeners();

    try {
      await _syncService?.start(
        uid: user.uid,
        deviceId: deviceId,
        onForcedLogout: _handleForcedLogout,
        bootstrap: needsBootstrap,
      );
      if (needsBootstrap) {
        await _waitForBootstrapData();
      }
      if (needsBootstrap || existingBootstrapVersion == null) {
        await Storage.setBootstrapVersionFlag(Storage.bootstrapVersion);
      }
    } finally {
      if (_isBootstrapping) {
        _isBootstrapping = false;
        notifyListeners();
      }
    }
  }

  Future<void> _waitForBootstrapData() async {
    final sync = _syncService;
    if (sync == null) return;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (sync.lastPull == null &&
        !sync.hasPulledUser &&
        sync.lastError == null) {
      if (DateTime.now().isAfter(deadline)) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (sync.lastPull == null && !sync.hasPulledUser) {
      final message = sync.lastError ??
          'Unable to download your data. Please check your connection and try again.';
      throw AuthFailure(message);
    }
  }

  Future<void> _registerPushToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveFcmToken(user.uid, token);
      }

      _fcmTokenSub?.cancel();
      _fcmTokenSub = messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        await _saveFcmToken(user.uid, newToken);
      });

      _fcmMessageSub?.cancel();
      _fcmMessageSub = FirebaseMessaging.onMessage.listen((message) async {
        final notification = message.notification;
        final title = notification?.title ?? 'Nudge';
        final body = notification?.body ?? '';
        if (body.isEmpty) return;
        final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        await Notifs.showImmediate(id: id, title: title, body: body);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register push notifications: $e');
      }
    }
  }

  Future<void> _saveFcmToken(String uid, String token) async {
    final platform =
        kIsWeb ? 'web' : defaultTargetPlatform.toString().split('.').last;
    final tokenRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token);
    await tokenRef.set(
      {
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _firestore.collection('users').doc(uid).set(
      {
        'fcmEnabled': true,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> _ensureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'device_id';
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    List<int> bytes;
    try {
      final rand = Random.secure();
      bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    } on UnsupportedError {
      final rand = Random();
      bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    }
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(key, generated);
    return generated;
  }

  Future<void> _handleForcedLogout() async {
    if (_forcedLoggedOut) return;
    _forcedLoggedOut = true;
    notifyListeners();
    await signOut();
  }

  Future<void> _clearLocalUserData(String uid) async {
    // Close Hive boxes but DO NOT delete them - preserve cache for re-login
    await Storage.closeForSignOut();

    // Clear session-specific state only (not cached data)
    UserStorage.setCurrentUser(uid);
    final userStorage = await UserStorage.getInstance();
    await userStorage.clearUserData();
    UserStorage.setCurrentUser(null);

    // Clear session-specific preferences only
    await _clearSharedPreferences();

    // Cancel notifications for this session
    await Notifs.cancelAll();
  }

  Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs
        .getKeys()
        .where((key) =>
            key.startsWith('timer_planned_') ||
            key.startsWith('progress_') ||
            key == 'onboarded_credits_v1' ||
            key == 'themeMode' ||
            key == 'device_id')
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  Future<void> reloadUser() async {
    try {
      await _currentUser?.reload();
    } catch (_) {}
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  Future<String?> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedDisplayName = displayName.trim();

    if (trimmedEmail.isEmpty) {
      return 'Email is required.';
    }
    if (!trimmedEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (trimmedDisplayName.isEmpty) {
      return 'Display name is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    _setBusy(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Unable to create an account right now. Please try again.';
      }

      if (user.displayName != trimmedDisplayName) {
        await user.updateDisplayName(trimmedDisplayName);
      }

      try {
        await user.sendEmailVerification();

        await Future.delayed(const Duration(seconds: 1));

        await _upsertEmailIndex(user.email, user.uid);

        return null;
      } catch (e) {
        return 'Failed to send verification email. Please try again.';
      }
    } on FirebaseAuthException catch (e) {
      return _messageForAuthCode(e.code);
    } on FirebaseException catch (e) {
      return e.message ?? 'Unable to save account data. Please try again.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Not logged in';
      }

      await user.reload();
      final refreshed = _auth.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        _handleAuthState(refreshed);
        return null;
      }

      return 'Email not verified yet. Please check your email and click the verification link.';
    } on FirebaseAuthException catch (e) {
      return _messageForAuthCode(e.code);
    } catch (e) {
      return 'Failed to check verification status. Please try again.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return 'Please enter your email.';
    }
    if (!trimmedEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    _setBusy(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _messageForAuthCode(e.code);
    } on AuthFailure catch (e) {
      return e.message;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _isSigningOut = true;
    notifyListeners();
    _syncReady = false;
    _initializingUser = null;
    _requiresEmailVerification = false;
    _isBootstrapping = false;
    await _syncService?.stop();
    UserStorage.setCurrentUser(null);
    await _auth.signOut();
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return 'Not signed in';

    _setBusy(true);
    try {
      final userId = user.uid;

      _syncReady = false;
      _initializingUser = null;
      await _syncService?.stop();

      await _deleteAccountRemote(user);
      _pendingAccountDeletedMessage = true;

      await _clearLocalUserData(userId);
      _currentUser = null;
      _profileData = null;
      _profileReady = false;
      _requiresEmailVerification = false;
      await _auth.signOut();
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (e) {
      return _messageForAuthCode(e.code);
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to delete account. Please try again.';
    } catch (e) {
      return 'Failed to delete account: $e';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deleteAccountRemote(User user) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('deleteAccountCallable');
    try {
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unimplemented' || e.code == 'not-found') {
        await _deleteAccountLocally(user);
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteAccountLocally(User user) async {
    final userId = user.uid;
    await _removeUserMemberships(userId);
    await _deleteGroupsOwnedBy(userId);
    await _deleteUserOwnedData(userId);
    await _deleteUserProfileDocument(userId);
    await user.delete();
  }

  Future<void> _deleteGroupsOwnedBy(String userId) async {
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('createdBy', isEqualTo: userId)
        .get();

    await Future.wait(
      groupsSnapshot.docs.map(_deleteOwnedGroupCascade),
    );
  }

  Future<void> _deleteOwnedGroupCascade(
    QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
  ) async {
    final groupRef = groupDoc.reference;
    final groupId = groupRef.id;

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      groupRef.collection('members').get(),
      groupRef.collection('invites').get(),
    ]);

    final membersSnapshot = results[0];
    final invitesSnapshot = results[1];

    final memberRefs =
        membersSnapshot.docs.map((doc) => doc.reference).toList();
    final inviteRefs =
        invitesSnapshot.docs.map((doc) => doc.reference).toList();

    final membershipRefs = membersSnapshot.docs
        .map((doc) => _firestore
            .collection('users')
            .doc(doc.id)
            .collection('groupMemberships')
            .doc(groupId))
        .toList();

    await Future.wait([
      _deleteDocumentRefs(memberRefs),
      _deleteDocumentRefs(inviteRefs),
      _deleteDocumentRefs(membershipRefs),
    ]);

    await groupRef.delete();
  }

  Future<void> _removeUserMemberships(String userId) async {
    final membershipSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('groupMemberships')
        .get();

    const chunkSize = 400;
    for (var i = 0; i < membershipSnapshot.docs.length; i += chunkSize) {
      final slice = membershipSnapshot.docs.sublist(
        i,
        min(i + chunkSize, membershipSnapshot.docs.length),
      );

      final groupSnapshots = await Future.wait(
        slice.map((m) => _firestore.collection('groups').doc(m.id).get()),
      );

      final batch = _firestore.batch();
      for (var j = 0; j < slice.length; j++) {
        final membership = slice[j];
        final groupSnap = groupSnapshots[j];
        final groupId = membership.id;
        final groupRef = _firestore.collection('groups').doc(groupId);

        batch.delete(groupRef.collection('members').doc(userId));
        batch.delete(groupRef.collection('aggregates').doc(userId));
        batch.delete(membership.reference);

        if (groupSnap.exists) {
          batch.set(
            groupRef,
            {
              'memberCount': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
      await batch.commit();
    }
  }

  Future<void> _deleteUserOwnedData(String userId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    const subcollections = [
      'courses',
      'studyTimes',
      'courseGoals',
      'courseProgress',
      'sessions',
      'studySessions',
      'goals',
      'reflections',
      'preferences',
      'groupMemberships',
      'meta',
      'aggregates',
    ];

    await Future.wait([
      for (final name in subcollections)
        _deleteQueryBatch(userDoc.collection(name))
    ]);
  }

  Future<void> _deleteUserProfileDocument(String userId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    await userDoc.delete();
  }

  Future<void> _deleteQueryBatch(
    Query<Map<String, dynamic>> query, {
    int batchSize = 250,
  }) async {
    while (true) {
      final snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      await _deleteDocumentRefs(
        snapshot.docs.map((doc) => doc.reference).toList(),
      );
      if (snapshot.docs.length < batchSize) break;
    }
  }

  Future<void> _deleteDocumentRefs(List<DocumentReference> refs) async {
    if (refs.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final slice = refs.sublist(i, min(i + chunkSize, refs.length));
      final batch = _firestore.batch();
      for (final ref in slice) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _ensureProfileDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'displayName': user.displayName ?? '',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileName': user.displayName ?? '',
        'profileComplete': false,
        'groupIds': <String>[],
        'isNewUser': true,
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'allowNudges': true,
        'fcmEnabled': false,
        'emailVerified': user.emailVerified,
      });
      return;
    }

    final data = snapshot.data() ?? {};
    final updates = <String, dynamic>{};
    final existingDisplayName = (data['displayName'] as String?)?.trim();
    final existingProfileName = (data['profileName'] as String?)?.trim();
    final userDisplayName = user.displayName?.trim();
    if (existingProfileName == null || existingProfileName.isEmpty) {
      if (userDisplayName != null && userDisplayName.isNotEmpty) {
        updates['profileName'] = userDisplayName;
        updates['displayName'] = userDisplayName;
      }
    } else if (existingDisplayName != existingProfileName) {
      updates['displayName'] = existingProfileName;
    } else if ((existingDisplayName == null || existingDisplayName.isEmpty) &&
        (userDisplayName != null && userDisplayName.isNotEmpty)) {
      updates['displayName'] = userDisplayName;
    }
    if ((data['email'] as String?) != user.email) {
      updates['email'] = user.email;
    }
    if (data['emailVerified'] != user.emailVerified) {
      updates['emailVerified'] = user.emailVerified;
    }
    if (data['updatedAt'] == null) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }
    final currentOffset = DateTime.now().timeZoneOffset.inMinutes;
    if (data['timezoneOffsetMinutes'] != currentOffset) {
      updates['timezoneOffsetMinutes'] = currentOffset;
    }
    if (data['allowNudges'] == null) {
      updates['allowNudges'] = true;
    }
    if (data['fcmEnabled'] == null) {
      updates['fcmEnabled'] = false;
    }
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  void _listenToProfile(User? user) {
    _profileSub?.cancel();
    _profileData = null;
    _profileReady = false;
    if (user == null) return;
    _profileSub = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      _profileData = snapshot.data();
      _profileReady = true;
      notifyListeners();
    }, onError: (error, stack) {
      if (kDebugMode) {
        print('Profile listener error: $error');
      }
      _profileData = null;
      _profileReady = true;
      notifyListeners();
    });
  }

  String _messageForAuthCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists for that login.';
      case 'invalid-email':
        return 'That login looks invalid. Try a different one.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect login or password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> _upsertEmailIndex(String? email, String uid) async {
    if (email == null || email.isEmpty) return;
    final normalized = _normalizeEmail(email);
    final ref = _firestore.collection('email_index').doc(normalized);
    await ref.set(
      {
        'uid': uid,
        'email': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<PasswordResetResult> sendPasswordResetSecure(String email) async {
    final trimmed = _normalizeEmail(email);
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return PasswordResetResult(
        success: false,
        verificationRequired: false,
        verificationEmailSent: false,
        message: 'Enter a valid email address.',
        code: 'invalid-email',
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastResetRequestMs < 15000) {
      return PasswordResetResult(
        success: false,
        verificationRequired: false,
        verificationEmailSent: false,
        message: 'Please wait a moment before trying again.',
        code: 'rate-limited',
      );
    }

    bool requiresVerification = false;
    bool verificationSent = false;

    try {
      final idxSnap =
          await _firestore.collection('email_index').doc(trimmed).get();
      final uid = idxSnap.data()?['uid'] as String?;
      if (uid != null && uid.isNotEmpty) {
        final profileSnap = await _firestore.collection('users').doc(uid).get();
        final verified = profileSnap.data()?['emailVerified'] == true;
        if (!verified) {
          requiresVerification = true;
          final current = _auth.currentUser;
          if (current != null &&
              _normalizeEmail(current.email ?? '') == trimmed) {
            try {
              await current.sendEmailVerification();
              verificationSent = true;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    if (requiresVerification) {
      return PasswordResetResult(
        success: false,
        verificationRequired: true,
        verificationEmailSent: verificationSent,
        message:
            'Please verify your email first. We sent you a verification email.',
        code: 'verification-required',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
      _lastResetRequestMs = nowMs;
      return const PasswordResetResult(
        success: true,
        verificationRequired: false,
        verificationEmailSent: false,
        message: 'If an account exists for this email, we sent a reset link.',
        code: 'sent',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      String? code;
      switch (e.code) {
        case 'invalid-email':
          message = 'Enter a valid email address.';
          code = 'invalid-email';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please wait and try again.';
          code = 'too-many-requests';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection and try again.';
          code = 'network';
          break;
        default:
          message =
              'If an account exists for this email, we sent a reset link.';
          code = 'sent';
      }
      return PasswordResetResult(
        success: false,
        verificationRequired: false,
        verificationEmailSent: false,
        message: message,
        code: code,
      );
    } catch (_) {
      return const PasswordResetResult(
        success: false,
        verificationRequired: false,
        verificationEmailSent: false,
        message: 'Something went wrong. Please try again.',
        code: 'unknown',
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _profileSub?.cancel();
    _fcmTokenSub?.cancel();
    _fcmMessageSub?.cancel();
    super.dispose();
  }
}

class PasswordResetResult {
  final bool success;
  final bool verificationRequired;
  final bool verificationEmailSent;
  final String message;
  final String? code;

  const PasswordResetResult({
    required this.success,
    required this.verificationRequired,
    required this.verificationEmailSent,
    required this.message,
    this.code,
  });
}
