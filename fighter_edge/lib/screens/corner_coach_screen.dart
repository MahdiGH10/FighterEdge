import 'package:flutter/material.dart';

import '../billing/subscription.dart';
import '../data/mock_data.dart';
import '../models/coach_cue.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/pro_lock.dart';
import '../widgets/stat_card.dart';

class CornerCoachScreen extends StatefulWidget {
  const CornerCoachScreen({super.key});

  @override
  State<CornerCoachScreen> createState() => _CornerCoachScreenState();
}

class _CornerCoachScreenState extends State<CornerCoachScreen> {
  int _round = 3;

  static const _pep = [
    'You\'re doing great. Keep pushing!\nStay sharp and trust your game plan.',
    'Hands up, chin down. This round is yours.',
    'Breathe and reset. Control the center.',
    'Dig deep — championship rounds are won here.',
  ];

  @override
  Widget build(BuildContext context) {
    final pep = _pep[(_round - 1) % _pep.length];
    return ScreenScaffold(
      title: 'Corner Coach',
      showBack: true,
      body: ProGate(
        feature: Feature.cornerCoach,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        children: [
          const SizedBox(height: Insets.md),
          Center(
            child: Text('ROUND $_round',
                style: AppTheme.display(30, color: AppColors.primary, spacing: 1)),
          ),
          const SizedBox(height: Insets.sm),
          Text(pep,
              textAlign: TextAlign.center,
              style: AppTheme.body(14,
                  weight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: Insets.xl),
          for (final c in MockData.coachCues) _CueCard(c),
          const SizedBox(height: Insets.md),
          PrimaryButton(
            'Next Round',
            expand: true,
            onPressed: () => setState(() => _round++),
          ),
        ],
        ),
      ),
    );
  }
}

class _CueCard extends StatelessWidget {
  final CoachCue cue;
  const _CueCard(this.cue);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cue.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cue.label,
                      style: AppTheme.body(12,
                          weight: FontWeight.w700, spacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(cue.message,
                      style: AppTheme.body(13,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
