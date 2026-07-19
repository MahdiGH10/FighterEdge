import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth/auth_repository.dart';
import 'auth/firebase_auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'data/data_repository.dart';
import 'data/firestore_data_repository.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // Production auth via Firebase. (LocalAuthRepository remains available as an
  // offline/dev fallback — see docs/firebase_setup.md.)
  final AuthRepository authRepo = FirebaseAuthRepository();
  await authRepo.init();

  runApp(FighterEdgeApp(
    authRepo: authRepo,
    dataRepo: FirestoreDataRepository(),
  ));
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  final DataRepository? dataRepo;
  const FighterEdgeApp({super.key, required this.authRepo, this.dataRepo});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(authRepo)),
        ChangeNotifierProxyProvider<AuthController, AppState>(
          create: (_) => AppState(dataRepository: dataRepo),
          update: (_, auth, state) {
            final appState = state ?? AppState(dataRepository: dataRepo);
            appState.setUser(auth.user?.id);
            return appState;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Fighter Edge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        color: AppColors.background,
        home: const AuthGate(),
      ),
    );
  }
}
