import 'dart:io';

import 'package:fighter_edge/debug/component_gallery_screen.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final oswald = FontLoader('Oswald')
      ..addFont(rootBundle.load('assets/fonts/Oswald-Variable.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(_loadMaterialIconsFont());
    await Future.wait([oswald.load(), inter.load(), materialIcons.load()]);
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Future<void> pumpGallery(
    WidgetTester tester, {
    required double textScale,
  }) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1700);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 1700),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: const ComponentGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('component gallery matches baseline at default text scale',
      (tester) async {
    await pumpGallery(tester, textScale: 1);

    await expectLater(
      find.byType(ComponentGalleryScreen),
      matchesGoldenFile('goldens/component_gallery_default.png'),
    );
  });

  testWidgets('component gallery survives large text scale', (tester) async {
    await pumpGallery(tester, textScale: 1.6);

    await expectLater(
      find.byType(ComponentGalleryScreen),
      matchesGoldenFile('goldens/component_gallery_large_text.png'),
    );
  });

  testWidgets('PressScale pressed state matches baseline', (tester) async {
    await pumpGallery(tester, textScale: 1);

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(PressScale).last));
    await tester.pump(MotionTokens.press);

    await expectLater(
      find.byType(ComponentGalleryScreen),
      matchesGoldenFile('goldens/component_gallery_pressed.png'),
    );

    await gesture.up();
  });
}

Future<ByteData> _loadMaterialIconsFont() async {
  const relativeFontPaths = [
    // Flutter's artifact name is case-sensitive on Linux runners. Windows
    // accepts both spellings, which previously masked this CI-only failure.
    'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ];

  final candidates = [
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      ...relativeFontPaths.map(
        (relativePath) => _joinPath([
          root,
          ...relativePath.split('/'),
        ]),
      ),
    ...relativeFontPaths.map(
      (relativePath) => _joinPath([
        'C:',
        'src',
        'flutter',
        ...relativePath.split('/'),
      ]),
    ),
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return ByteData.sublistView(await file.readAsBytes());
    }
  }

  throw StateError('Material Icons font not found for golden tests.');
}

String _joinPath(List<String> parts) => parts.join(Platform.pathSeparator);
