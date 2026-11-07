import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DeleteAccountFailure { wrongPassword, network, failed }

DeleteAccountFailure deleteAccountFailureFor(String code) {
  switch (code) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return DeleteAccountFailure.wrongPassword;
    case 'network-request-failed':
      return DeleteAccountFailure.network;
    default:
      return DeleteAccountFailure.failed;
  }
}

// a fresh token carries the new auth_time the server checks for a recent sign-in
Future<DeleteAccountFailure?> reauthenticateForDeletion(
  User user,
  String password,
) async {
  final email = user.email;
  if (email == null) return DeleteAccountFailure.failed;
  try {
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    await user.getIdToken(true);
    return null;
  } on FirebaseAuthException catch (e) {
    return deleteAccountFailureFor(e.code);
  }
}

// the default instance is resolved here so a controller can be built without firebase in tests
Future<bool> requestServerDeletion(FirebaseFunctions? functions) async {
  final client = functions ?? FirebaseFunctions.instance;
  try {
    await client.httpsCallable('deleteAccountCallable').call();
    return true;
  } on FirebaseFunctionsException {
    return false;
  }
}
