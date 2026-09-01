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
import 'features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/ai/firebase_edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/data/edge_fuel_repository.dart';
import 'features/edge_fuel/data/firestore_edge_fuel_repository.dart';
import 'features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
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
    edgeFuelRepo: FirestoreEdgeFuelRepository(),
    edgeFuelAiGateway: FirebaseEdgeFuelAiGateway(),
  ));
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  final DataRepository? dataRepo;
  final EdgeFuelRepository? edgeFuelRepo;
  final EdgeFuelAiGateway? edgeFuelAiGateway;
  const FighterEdgeApp({
    super.key,
    required this.authRepo,
    this.dataRepo,
    this.edgeFuelRepo,
    this.edgeFuelAiGateway,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedEdgeFuelRepo = edgeFuelRepo ?? InMemoryEdgeFuelRepository();
    final resolvedAiGateway =
        edgeFuelAiGateway ?? const FakeEdgeFuelAiGateway();
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
        Provider<EdgeFuelRepository>.value(value: resolvedEdgeFuelRepo),
        Provider<EdgeFuelAiGateway>.value(value: resolvedAiGateway),
        ChangeNotifierProxyProvider<AuthController, EdgeFuelController>(
          create: (_) => EdgeFuelController(repository: resolvedEdgeFuelRepo),
          update: (_, auth, controller) {
            final edgeFuel = controller ??
                EdgeFuelController(repository: resolvedEdgeFuelRepo);
            edgeFuel.setUser(auth.user?.id);
            return edgeFuel;
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
