import 'package:firebase_auth/firebase_auth.dart';

import 'package:numer_app/core/identity/id_token_provider.dart';

class ModuleSession {
  ModuleSession({
    required this.idToken,
    required Future<void> Function() signOut,
  }) : _signOut = signOut;

  final IdTokenProvider idToken;
  final Future<void> Function() _signOut;

  Future<String?>? _inFlight;

  // modules that hit a 401 together share one refresh
  Future<String?> handleSessionExpired() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    try {
      return await idToken(forceRefresh: true);
    } on FirebaseAuthException {
      await _signOut();
      return null;
    } on SignedOutException {
      await _signOut();
      return null;
    }
  }
}
