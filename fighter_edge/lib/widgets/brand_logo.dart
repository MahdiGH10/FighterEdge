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
        Container(
          width: 56 * scale,
          height: 56 * scale,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Icon(Icons.sports_mma,
              color: AppColors.primary, size: 30 * scale),
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
