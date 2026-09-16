import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'progress_ring.dart';

/// Row of M–S completion rings for the dashboard weekly overview.
class WeeklyOverview extends StatelessWidget {
  final List<String> dayLetters;
  final List<double> progress;
  final int todayIndex;

  const WeeklyOverview({
    super.key,
    required this.dayLetters,
    required this.progress,
    required this.todayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < dayLetters.length; i++)
          Column(
            children: [
              Text(
                dayLetters[i],
                style: AppType.micro(
                    weight: FontWeight.w600,
                    color: i == todayIndex
                        ? AppColors.primary
                        : AppColors.textMuted),
              ),
              const SizedBox(height: Insets.sm),
              ProgressRing(
                progress: progress[i],
                size: 30,
                strokeWidth: 3,
                child: i == todayIndex
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}
