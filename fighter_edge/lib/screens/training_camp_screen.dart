import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/training_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';

class TrainingCampScreen extends StatefulWidget {
  const TrainingCampScreen({super.key});

  @override
  State<TrainingCampScreen> createState() => _TrainingCampScreenState();
}

class _TrainingCampScreenState extends State<TrainingCampScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              title: 'Training Camp',
              showBack: false,
              actions: [HeaderIcon(Icons.calendar_month, onTap: () {})],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: FilterChips(
                options: const ['Week', 'Month', 'Plan'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
                scrollable: false,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _WeekView(),
                  _PlaceholderView('Monthly calendar coming soon'),
                  _PlaceholderView('Full fight-camp plan coming soon'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('WEEK 4', style: AppTheme.display(20)),
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('PEAK',
                  style: AppTheme.body(11,
                      weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('May 20 – May 26',
            style: AppTheme.body(12,
                weight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: Insets.lg),
        for (final s in MockData.week) _SessionRow(s),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final TrainingSession s;
  const _SessionRow(this.s);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(s.day.toUpperCase(),
                  style: AppTheme.body(12,
                      weight: FontWeight.w700, color: AppColors.textMuted)),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon,
                  size: 20,
                  color: s.completed
                      ? AppColors.primary
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: AppTheme.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.subtitle,
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            _CompletionDot(completed: s.completed),
          ],
        ),
      ),
    );
  }
}

class _CompletionDot extends StatelessWidget {
  final bool completed;
  const _CompletionDot({required this.completed});

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String message;
  const _PlaceholderView(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Text(message,
            textAlign: TextAlign.center,
            style: AppTheme.body(14,
                weight: FontWeight.w500, color: AppColors.textMuted)),
      ),
    );
  }
}
