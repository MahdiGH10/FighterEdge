import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../models/coach_cue.dart';
import '../models/training_session.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_ring.dart';

enum _Phase { work, rest, done }

class RoundTimerScreen extends StatefulWidget {
  final TrainingSession? session;
  const RoundTimerScreen({super.key, this.session});

  @override
  State<RoundTimerScreen> createState() => _RoundTimerScreenState();
}

class _RoundTimerScreenState extends State<RoundTimerScreen> {
  int _styleIndex = 1; // MMA
  Timer? _ticker;
  bool _running = false;

  late TimerStyle _style;
  late int _round;
  late _Phase _phase;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _style = MockData.timerStyles[_styleIndex];
    _resetToStart();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _resetToStart() {
    _ticker?.cancel();
    _running = false;
    _round = 1;
    _phase = _Phase.work;
    _secondsLeft = _style.workSeconds;
  }

  void _selectStyle(int i) {
    setState(() {
      _styleIndex = i;
      _style = MockData.timerStyles[i];
      _resetToStart();
    });
  }

  void _toggle() {
    if (_phase == _Phase.done) {
      setState(_resetToStart);
      return;
    }
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _reset() => setState(_resetToStart);

  void _tick() {
    setState(() {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        return;
      }
      // Clock reached 00:00 — advance to the next phase.
      if (_phase == _Phase.work) {
        if (_round >= _style.rounds) {
          _phase = _Phase.done;
          _running = false;
          _ticker?.cancel();
          _secondsLeft = 0;
          HapticFeedback.heavyImpact();
          final session = widget.session;
          if (session != null) {
            context.read<AppState>().completeSession(
                  session,
                  rpe: 7,
                  note: 'Completed from round timer',
                );
          }
        } else {
          _phase = _Phase.rest;
          _secondsLeft = _style.restSeconds;
          HapticFeedback.mediumImpact();
        }
      } else {
        // rest -> next work round
        _round++;
        _phase = _Phase.work;
        _secondsLeft = _style.workSeconds;
        HapticFeedback.mediumImpact();
      }
    });
  }

  String get _clock {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    final total =
        _phase == _Phase.rest ? _style.restSeconds : _style.workSeconds;
    if (total == 0) return 0;
    return 1 - (_secondsLeft / total);
  }

  Color get _phaseColor =>
      _phase == _Phase.rest ? AppColors.warning : AppColors.primary;

  String get _phaseLabel => switch (_phase) {
        _Phase.work => 'WORK',
        _Phase.rest => 'REST',
        _Phase.done => 'DONE',
      };

  String get _nextLabel {
    if (_phase == _Phase.done) return 'Session complete';
    if (_phase == _Phase.work) {
      return _round >= _style.rounds ? 'Final round' : 'Rest';
    }
    return 'Round ${_round + 1}';
  }

  int get _nextSeconds => _phase == _Phase.work
      ? (_round >= _style.rounds ? 0 : _style.restSeconds)
      : _style.workSeconds;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final urgent = _running && _phase == _Phase.work && _secondsLeft <= 10;
    return ScreenScaffold(
      title: 'Round Timer',
      showBack: true,
      actions: [HeaderIcon(Icons.settings_outlined, onTap: () {})],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        child: Column(
          children: [
            FilterChips(
              options: [for (final s in MockData.timerStyles) s.name],
              selectedIndex: _styleIndex,
              onSelected: _selectStyle,
              scrollable: false,
            ),
            const SizedBox(height: Insets.xxl),
            Text('Round',
                style: AppTheme.body(12,
                    weight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text('$_round / ${_style.rounds}', style: AppTheme.display(22)),
            const SizedBox(height: Insets.xl),
            TweenAnimationBuilder<double>(
              key: ValueKey(urgent ? _secondsLeft : _phaseLabel),
              tween: Tween(begin: urgent ? 1.035 : 1.0, end: 1.0),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: ProgressRing(
                progress: _progress,
                size: 260,
                strokeWidth: urgent ? 14 : 12,
                color: _phaseColor,
                trackColor: urgent
                    ? AppColors.primarySoft.withValues(alpha: .35)
                    : AppColors.track,
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : MotionTokens.fast,
                  child: Column(
                    key: ValueKey('$_clock-$_phaseLabel'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_clock,
                          style: AppTheme.display(64,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: Insets.xs),
                      Text(_phaseLabel,
                          style: AppTheme.display(18,
                              color: _phaseColor, spacing: 3)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text('Next: $_nextLabel',
                style: AppTheme.body(13,
                    weight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(_fmt(_nextSeconds), style: AppTheme.display(20)),
            const SizedBox(height: Insets.xxl),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    _phase == _Phase.done
                        ? 'Restart'
                        : (_running ? 'Pause' : 'Start'),
                    icon: _phase == _Phase.done
                        ? Icons.refresh
                        : (_running ? Icons.pause : Icons.play_arrow),
                    expand: true,
                    color: _running ? AppColors.primaryDark : AppColors.primary,
                    onPressed: _toggle,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GhostButton('Reset',
                      icon: Icons.stop, expand: true, onPressed: _reset),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
