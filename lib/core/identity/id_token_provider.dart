import 'package:firebase_auth/firebase_auth.dart';

typedef IdTokenProvider = Future<String> Function({bool forceRefresh});

final class SignedOutException implements Exception {
  const SignedOutException();
}

IdTokenProvider firebaseIdTokenProvider(FirebaseAuth auth) {
  return ({bool forceRefresh = false}) async {
    final user = auth.currentUser;
    if (user == null) throw const SignedOutException();
    final token = await user.getIdToken(forceRefresh);
    if (token == null) throw const SignedOutException();
    return token;
  };
}
