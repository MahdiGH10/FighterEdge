import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
          width: 58 * scale,
          height: 58 * scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: .56,
                child: Container(
                  width: 7 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                ),
              ),
              Text('FE',
                  style: AppTheme.display(22 * scale,
                      weight: FontWeight.w800, spacing: .4)),
            ],
          ),
        ),
        SizedBox(height: 14 * scale),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: 'FIGHTER ',
                  style: AppTheme.display(28 * scale, spacing: 1.5)),
              TextSpan(
                  text: 'EDGE',
                  style: AppTheme.display(28 * scale,
                      color: AppColors.primary, spacing: 1.5)),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: 4 * scale),
          Text('YOUR EDGE. EVERY DAY.',
              style: AppTheme.body(11 * scale,
                  weight: FontWeight.w600,
                  color: AppColors.textMuted,
                  spacing: 2)),
        ],
      ],
    );
  }
}
