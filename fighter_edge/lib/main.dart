import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth/auth_repository.dart';
import 'auth/firebase_auth_repository.dart';
import 'controllers/auth_controller.dart';
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

  // Production auth via Firebase. (LocalAuthRepository remains available as an
  // offline/dev fallback — see docs/firebase_setup.md.)
  final AuthRepository authRepo = FirebaseAuthRepository();
  await authRepo.init();

  runApp(FighterEdgeApp(authRepo: authRepo));
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  const FighterEdgeApp({super.key, required this.authRepo});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(authRepo)),
        ChangeNotifierProvider(create: (_) => AppState()),
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
