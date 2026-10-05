import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/theme/app_icons.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/app_text_field.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

double contrast(Color foreground, Color background) {
  double luminance(Color color) {
    double linear(double value) => value <= .04045
        ? value / 12.92
        : math.pow((value + .055) / 1.055, 2.4).toDouble();
    return .2126 * linear(color.r) +
        .7152 * linear(color.g) +
        .0722 * linear(color.b);
  }

  final a = luminance(foreground);
  final b = luminance(background);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  for (final highContrast in [false, true]) {
    testWidgets('rendered input labels pass contrast, high=$highContrast',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: MediaQueryData(
                highContrast: highContrast, textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: AppTextField(
                    controller: controller,
                    label: 'Email',
                    icon: AppIcons.envelopeSimple)),
          )));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      final labelStyle = decoration.floatingLabelStyle as WidgetStateTextStyle;
      for (final states in [
        <WidgetState>{WidgetState.focused},
        <WidgetState>{WidgetState.focused, WidgetState.error}
      ]) {
        expect(
            contrast(labelStyle.resolve(states).color!, decoration.fillColor!),
            greaterThanOrEqualTo(4.5));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('actual timer Start and Pause fills carry readable white labels',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const RoundTimerScreen(), repo: repo));
    await tester.pumpAndSettle();
    PrimaryButton button() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(contrast(AppColors.onPrimary, button().color),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(contrast(AppColors.onPrimary, button().color),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    expect(contrast(AppColors.onPrimary, button().color),
        greaterThanOrEqualTo(4.5));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
