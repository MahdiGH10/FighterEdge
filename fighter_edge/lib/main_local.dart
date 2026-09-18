import 'package:flutter/material.dart';

import 'auth/local_auth_repository.dart';
import 'data/in_memory_data_repository.dart';
import 'main.dart';

/// Offline entry point: the whole app on the on-device auth backend, with no
/// Firebase, no network and no real accounts.
///
///     flutter run -t lib/main_local.dart
///
/// For walking signup, onboarding and the first-week flow without leaving
/// throwaway accounts in the live project. Everything is stored locally and
/// disappears with the browser or app data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = LocalAuthRepository();
  await repo.init();
  // An empty in-memory store rather than none: with no repository AppState
  // falls back to demo seed data, which would make a brand-new account look
  // like it had already trained. Training and weight data reset on reload.
  runApp(FighterEdgeApp(authRepo: repo, dataRepo: InMemoryDataRepository()));
}
