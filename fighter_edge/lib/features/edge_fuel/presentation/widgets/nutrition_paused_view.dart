import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_icons.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/primary_button.dart';
import '../../domain/policies/nutrition_display_mode.dart';
import '../controllers/nutrition_mode_controller.dart';

/// What a nutrition screen shows while nutrition is paused: one calm note and
/// one way back. No numbers, no food, no weight, and nothing that asks the
/// athlete to explain or justify the pause.
class NutritionPausedView extends StatelessWidget {
  const NutritionPausedView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final secondary = AppAccessibility.textSecondary(context);
    // Numbers hidden is a lighter step than paused: food can still be logged by
    // name, so the note says only what is hidden.
    final hidden = context.watch<NutritionModeController>().mode ==
        NutritionDisplayMode.hideNumbers;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.moon, color: secondary),
            const SizedBox(height: Insets.lg),
            Text(
              hidden ? l.nutritionNumbersHiddenTitle : l.nutritionPausedTitle,
              style: AppType.title1(),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              hidden ? l.nutritionNumbersHiddenBody : l.nutritionPausedBody,
              style: AppType.body(color: secondary),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              hidden ? l.nutritionNumbersHiddenShow : l.nutritionPausedResume,
              expand: true,
              onPressed: () {
                AppHaptics.commit();
                context
                    .read<NutritionModeController>()
                    .setMode(NutritionDisplayMode.normal);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A whole screen that only makes sense with nutrition on (the weight tracker,
/// the fight path): the paused note under the screen's own title, or nothing
/// at all until the athlete's choice is known.
class NutritionPausedScreen extends StatelessWidget {
  const NutritionPausedScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final loaded = context.watch<NutritionModeController>().loaded;
    return ScreenScaffold(
      title: title,
      showBack: true,
      body: loaded ? const NutritionPausedView() : const SizedBox.shrink(),
    );
  }
}
