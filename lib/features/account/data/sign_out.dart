import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/auth/auth.dart';

Future<void> signOutAndReset(BuildContext context) async {
  final appState = context.read<AppState>();
  final sync = context.read<SyncService>();
  final auth = context.read<AuthController>();
  await appState.stopAndSaveAllActiveSessions();
  await appState.waitForPendingReflections();
  await sync.pushNow();
  await auth.signOut();
  appState.reset();
}
