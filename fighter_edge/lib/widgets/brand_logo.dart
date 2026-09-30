import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The FIGHTER EDGE wordmark used on auth screens.
class BrandLogo extends StatelessWidget {
  final double scale;
  final bool showTagline;
  const BrandLogo({super.key, this.scale = 1, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: LayoutTokens.brandMark * scale,
          height: LayoutTokens.brandMark * scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
              Transform.rotate(
                angle: .56,
                child: Container(
                  width: LayoutTokens.brandStroke * scale,
                  height: LayoutTokens.brandSlash * scale,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright,
                    borderRadius: BorderRadius.circular(Radii.tile * scale),
                  ),
                ),
              ),
              Text('FE',
                  style: AppType.scaledDisplay(22 * scale,
                      weight: FontWeight.w700, spacing: .4)),
            ],
          ),
        ),
        SizedBox(height: Insets.md + Insets.xxs * scale),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: 'FIGHTER ',
                  style: AppType.scaledDisplay(28 * scale, spacing: 1.5)),
              TextSpan(
                  text: 'EDGE',
                  style: AppType.scaledDisplay(28 * scale,
                      color: AppColors.accentText, spacing: 1.5)),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: Insets.xs * scale),
          Text('YOUR EDGE. EVERY DAY.',
              style: AppType.scaledBody(11 * scale,
                  weight: FontWeight.w600,
                  color: AppColors.textMuted,
                  spacing: 2)),
        ],
      ],
    );
  }
}
