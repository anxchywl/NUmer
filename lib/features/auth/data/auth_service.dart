import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/core/notifications/notifications.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/data/user_storage.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'account_deletion.dart';
import 'auth_code_api.dart';
import 'auth_write_gates.dart';
import 'email_verification.dart';
import 'local_user_data.dart';
import 'password_reset.dart';

export 'account_deletion.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

class AuthController extends ChangeNotifier
    with EmailVerification, PasswordReset {
  AuthController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AuthCodeApi? codeApi,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsOverride = functions,
       codeApi = codeApi ?? FunctionsAuthCodeApi() {
    _subscription = _auth.authStateChanges().listen(_handleAuthState);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;
  @override
  final AuthCodeApi codeApi;
  SyncService? _syncService;
  late final StreamSubscription<User?> _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<String>? _fcmTokenSub;
  StreamSubscription<RemoteMessage>? _fcmMessageSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nudgesSub;

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

  User? get currentUser => _currentUser;
  @override
  FirebaseAuth get firebaseAuth => _auth;
  Map<String, dynamic>? get profile => _profileData;
  bool get isProfileReady => _profileReady;
  bool get isBusy => _isBusy;
  bool get isInitialized => _initialized;
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
      _nudgesSub?.cancel();
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
    // creating the profile writes fcmEnabled false, so the token must be saved after it
    unawaited(
      _ensureProfileDocument(user).whenComplete(() async {
        if (_currentUser?.uid != user.uid) return;
        await _registerPushToken(user);
      }),
    );
    _listenToProfile(user);
    _listenForPendingNudges(user.uid);
    lastPreparationError = null;
    _forcedLoggedOut = false;
    UserStorage.setCurrentUser(user.uid);
    _startPreparation(user);
    notifyListeners();
  }

  void _startPreparation(User user) {
    _syncReady = false;
    final future = _prepareUser(user);
    _initializingUser = future;
    unawaited(
      future
          .then((_) {
            if (identical(_initializingUser, future)) {
              _syncReady = true;
              _initializingUser = null;
              notifyListeners();
            }
          })
          .catchError((error, stack) {
            if (kDebugMode) {
              print('Failed to prepare user data: $error\n$stack');
            }
            lastPreparationError = error.toString();
            notifyListeners();
          }),
    );
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

    final erase = !hasUnsyncedChanges(LocalDatabase.instance);
    await _syncService?.stop();
    if (previousUid != null) {
      await _clearLocalUserData(previousUid, erase: erase);
    } else {
      await Storage.closeForSignOut();
    }
  }

  Future<void> _prepareUser(User user) async {
    await Storage.configureForUser(user.uid);
    final deviceId = await _ensureDeviceId();
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
      final message =
          sync.lastError ??
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
    final prefs = await SharedPreferences.getInstance();
    final tokenKey = 'fcm_saved_token_$uid';
    final savedAtKey = 'fcm_saved_at_$uid';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!shouldSaveFcmToken(
      token,
      prefs.getString(tokenKey),
      prefs.getInt(savedAtKey),
      nowMs,
    )) {
      return;
    }
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform.toString().split('.').last;
    final tokenRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token);
    await tokenRef.set({
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(uid).set({
      'fcmEnabled': true,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await prefs.setString(tokenKey, token);
    await prefs.setInt(savedAtKey, nowMs);
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

  Future<void> _clearLocalUserData(String uid, {required bool erase}) async {
    await closeLocalUserData(uid, erase: erase);
    await Notifs.cancelAll();
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

      return null;
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

  @override
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

  // re-authentication comes first so a wrong password leaves sync and local data untouched
  Future<DeleteAccountFailure?> deleteAccount({
    required String password,
    Future<void> Function()? beforeDelete,
  }) async {
    final user = _currentUser;
    if (user == null) return DeleteAccountFailure.failed;

    _setBusy(true);
    try {
      final failure = await reauthenticateForDeletion(user, password);
      if (failure != null) return failure;

      await beforeDelete?.call();
      _syncReady = false;
      _initializingUser = null;
      await _syncService?.stop();

      if (!await requestServerDeletion(_functionsOverride)) {
        _startPreparation(user);
        return DeleteAccountFailure.failed;
      }

      _pendingAccountDeletedMessage = true;
      await _clearLocalUserData(user.uid, erase: true);
      _currentUser = null;
      _profileData = null;
      _profileReady = false;
      _requiresEmailVerification = false;
      await _auth.signOut();
      notifyListeners();
      return null;
    } finally {
      _setBusy(false);
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
        .listen(
          (snapshot) {
            _profileData = snapshot.data();
            _profileReady = true;
            notifyListeners();
          },
          onError: (error, stack) {
            if (kDebugMode) {
              print('Profile listener error: $error');
            }
            _profileData = null;
            _profileReady = true;
            notifyListeners();
          },
        );
    _listenForPendingNudges(user.uid); // Added this line
  }

  void _listenForPendingNudges(String uid) {
    _nudgesSub?.cancel();
    _nudgesSub = _firestore
        .collection('nudges')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data == null) continue;

                final title = data['title'] as String? ?? 'Nudge';
                final body = data['body'] as String? ?? '';

                if (body.isNotEmpty) {
                  final id = DateTime.now().millisecondsSinceEpoch.remainder(
                    100000,
                  );
                  Notifs.showImmediate(id: id, title: title, body: body);
                }

                change.doc.reference.update({'status': 'delivered'});
              }
            }
          },
          onError: (e) {
            if (kDebugMode) print('Nudges listener error: $e');
          },
        );
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

  @override
  void dispose() {
    _subscription.cancel();
    _profileSub?.cancel();
    _fcmTokenSub?.cancel();
    _fcmMessageSub?.cancel();
    super.dispose();
  }
}
