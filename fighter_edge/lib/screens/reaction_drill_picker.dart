import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_icons.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/reaction/coach_voice.dart';
import '../training/reaction/coach_voice_choice.dart';
import '../training/reaction/reaction_cue_generator.dart';
import '../training/reaction/reaction_drill.dart';
import '../training/reaction/selectable_coach_voice.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/premium_effects.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import 'reaction_drill_screen.dart';

String reactionDisciplineLabel(L l, ReactionDiscipline d) => switch (d) {
      ReactionDiscipline.grappling => l.reactionDisciplineGrappling,
      ReactionDiscipline.striking => l.reactionDisciplineStriking,
      ReactionDiscipline.mma => l.reactionDisciplineMma,
    };

String reactionLevelLabel(L l, ReactionLevel level) => switch (level) {
      ReactionLevel.beginner => l.reactionLevelBeginner,
      ReactionLevel.intermediate => l.reactionLevelIntermediate,
      ReactionLevel.advanced => l.reactionLevelAdvanced,
      ReactionLevel.advancedPlus => l.reactionLevelAdvancedPlus,
    };

String reactionVoiceLabel(L l, CoachVoiceChoice voice) => switch (voice) {
      CoachVoiceChoice.usMale => l.reactionVoiceUsMale,
      CoachVoiceChoice.ukMale => l.reactionVoiceUkMale,
      CoachVoiceChoice.usFemale => l.reactionVoiceUsFemale,
      CoachVoiceChoice.phone => l.reactionVoicePhone,
    };

String reactionPaceLabel(L l, ReactionPace pace) => switch (pace) {
      ReactionPace.steady => l.reactionPaceSteady,
      ReactionPace.sprint => l.reactionPaceSprint,
    };

/// "0:30", "2:30".
String formatDrillClock(Duration d) {
  final seconds = d.inSeconds.clamp(0, 24 * 60 * 60);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Train > Reaction: pick a discipline and level, see what it asks of you,
/// start.
class ReactionDrillPicker extends StatefulWidget {
  const ReactionDrillPicker({super.key});

  @override
  State<ReactionDrillPicker> createState() => _ReactionDrillPickerState();
}

class _ReactionDrillPickerState extends State<ReactionDrillPicker> {
  static const _disciplineKey = 'reaction.discipline';
  static const _levelKey = 'reaction.level';
  static const _paceKey = 'reaction.pace';

  var _discipline = ReactionDiscipline.mma;
  var _level = ReactionLevel.beginner;
  var _pace = ReactionPace.steady;

  ReactionDrillSpec get _spec =>
      ReactionDrillSpec.of(_discipline, _level, pace: _pace);

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  /// Athletes repeat the same drill; open on the one they picked last.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final discipline =
          _byName(ReactionDiscipline.values, prefs.getString(_disciplineKey));
      final level = _byName(ReactionLevel.values, prefs.getString(_levelKey));
      final pace = _byName(ReactionPace.values, prefs.getString(_paceKey));
      if (!mounted) return;
      setState(() {
        _discipline = discipline ?? _discipline;
        _level = level ?? _level;
        _pace = pace ?? _pace;
      });
    } catch (_) {
      // Remembering the choice is a convenience; the defaults are fine.
    }
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  void _select({
    ReactionDiscipline? discipline,
    ReactionLevel? level,
    ReactionPace? pace,
  }) {
    setState(() {
      _discipline = discipline ?? _discipline;
      _level = level ?? _level;
      _pace = pace ?? _pace;
    });
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_disciplineKey, _discipline.name);
        await prefs.setString(_levelKey, _level.name);
        await prefs.setString(_paceKey, _pace.name);
      } catch (_) {}
    }());
  }

  /// Speaks a real call from the chosen level, so the athlete finds a muted
  /// phone or low volume *before* getting into stance — and hears the pace.
  Future<void> _testVoice() async {
    final voice = context.read<CoachVoice>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final noVoice = L.of(context).reactionNoVoice;
    await voice.prepare();
    if (!voice.isAvailable) {
      messenger?.showSnackBar(SnackBar(content: Text(noVoice)));
      return;
    }
    await voice.stop();
    await voice.say(ReactionCueGenerator(_spec).next().spoken);
  }

  /// Switches the coach and lets the athlete hear it straight away.
  Future<void> _pickVoice(
      SelectableCoachVoice voices, CoachVoiceChoice choice) async {
    await voices.select(choice);
    if (!mounted) return;
    await _testVoice();
  }

  void _start() {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => ReactionDrillScreen(spec: _spec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final spec = _spec;
    final voices = context.read<SelectableCoachVoice?>();
    return ListView(
      padding: EdgeInsets.fromLTRB(Insets.lg, Insets.none, Insets.lg,
          ScreenScaffold.tabBottomPadding(context)),
      children: [
        PremiumReveal(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.reactionHeadline.toUpperCase(), style: AppType.title1()),
              const SizedBox(height: Insets.xxs),
              Text(
                l.reactionSoundHint,
                style: AppType.subhead(
                    weight: FontWeight.w500,
                    color: AppAccessibility.textSecondary(context)),
              ),
              if (voices != null) ...[
                const SizedBox(height: Insets.md),
                Text(
                  l.reactionCoachVoice.toUpperCase(),
                  style: AppType.micro(
                      weight: FontWeight.w800,
                      color: AppAccessibility.textMuted(context)),
                ),
                const SizedBox(height: Insets.xs),
                ValueListenableBuilder<CoachVoiceChoice>(
                  valueListenable: voices.choiceListenable,
                  builder: (context, choice, _) => FilterChips(
                    options: [
                      for (final v in CoachVoiceChoice.values)
                        reactionVoiceLabel(l, v),
                    ],
                    selectedIndex: choice.index,
                    onSelected: (i) =>
                        _pickVoice(voices, CoachVoiceChoice.values[i]),
                    columns: 2,
                  ),
                ),
              ],
              const SizedBox(height: Insets.sm),
              GhostButton(
                l.reactionTestVoice,
                icon: AppIcons.speakerHigh,
                onPressed: _testVoice,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        PremiumReveal(
          index: 1,
          child: FilterChips(
            options: [
              for (final d in ReactionDiscipline.values)
                reactionDisciplineLabel(l, d),
            ],
            selectedIndex: _discipline.index,
            onSelected: (i) =>
                _select(discipline: ReactionDiscipline.values[i]),
            scrollable: false,
          ),
        ),
        const SizedBox(height: Insets.sm),
        PremiumReveal(
          index: 2,
          // Four fixed levels: all of them visible at once, never scrolled
          // out of sight.
          child: FilterChips(
            options: [
              for (final level in ReactionLevel.values)
                reactionLevelLabel(l, level),
            ],
            selectedIndex: _level.index,
            onSelected: (i) => _select(level: ReactionLevel.values[i]),
            columns: 2,
          ),
        ),
        const SizedBox(height: Insets.sm),
        PremiumReveal(
          index: 3,
          child: FilterChips(
            options: [
              for (final p in ReactionPace.values) reactionPaceLabel(l, p),
            ],
            selectedIndex: _pace.index,
            onSelected: (i) => _select(pace: ReactionPace.values[i]),
            scrollable: false,
          ),
        ),
        const SizedBox(height: Insets.lg),
        PremiumReveal(index: 4, child: _SpecCard(spec: spec)),
        const SizedBox(height: Insets.xl),
        PremiumReveal(index: 5, child: _MoveList(spec: spec)),
        const SizedBox(height: Insets.xl),
        PremiumReveal(
          index: 6,
          child: PrimaryButton(
            l.reactionStart,
            icon: AppIconsFill.play,
            expand: true,
            onPressed: _start,
          ),
        ),
      ],
    );
  }
}

/// Duration and reaction time — the two numbers that make a level harder than
/// the one before it — plus any extra reset or rest time.
class _SpecCard extends StatelessWidget {
  final ReactionDrillSpec spec;
  const _SpecCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final seconds =
        NumberFormat('0.0', Localizations.localeOf(context).toString());
    String range(int minMs, int maxMs) =>
        '${seconds.format(minMs / 1000)}–${seconds.format(maxMs / 1000)}';

    final (fastest, slowest) = spec.reactionMs;
    final stats = [
      _Stat(
          label: l.reactionStatDuration,
          value: '${spec.rounds} × ${formatDrillClock(spec.roundDuration)}'),
      _Stat(label: l.reactionStatReact, value: '${range(fastest, slowest)} s'),
    ];

    final blockRest = spec.blockRest;
    final notes = [
      l.reactionRoundRestNote(formatDrillClock(spec.restDuration)),
      l.reactionMoveTimeNote,
      if (blockRest != null)
        l.reactionBlockRestNote(
            seconds.format(blockRest.rest.inMilliseconds / 1000),
            blockRest.minCalls,
            blockRest.maxCalls),
    ];

    // Columns only while the labels fit; at large text they stack so
    // no label breaks mid-word and no unit is orphaned on its own line.
    final Widget statLayout = AppAccessibility.isLargeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(height: Insets.md),
                stats[i],
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: Insets.md),
                Expanded(child: stats[i]),
              ],
            ],
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statLayout,
          for (final note in notes) ...[
            const SizedBox(height: Insets.sm),
            Text(
              note,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppType.micro(
                weight: FontWeight.w800,
                color: AppAccessibility.textMuted(context)),
          ),
          const SizedBox(height: Insets.xxs),
          Text(value, style: AppType.title2()),
        ],
      ),
    );
  }
}

/// The moves this drill calls, as plain text — reference, not controls, so
/// nothing here looks tappable. Two lines until the athlete asks for all.
class _MoveList extends StatefulWidget {
  final ReactionDrillSpec spec;
  const _MoveList({required this.spec});

  @override
  State<_MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<_MoveList> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final commands = widget.spec.discipline.commands;
    final text = commands.map((c) => c.label).join('  ·  ');
    final style =
        AppType.callout(color: AppAccessibility.textSecondary(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.reactionInTheMix(commands.length),
          style: AppType.micro(
              weight: FontWeight.w800,
              color: AppAccessibility.textMuted(context)),
        ),
        const SizedBox(height: Insets.sm),
        LayoutBuilder(builder: (context, constraints) {
          // Offer "show all" only when two lines really do cut the list.
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
          )..layout(maxWidth: constraints.maxWidth);
          final clipped = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: style,
                maxLines: _expanded ? null : 2,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (clipped)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, AppAccessibility.minTouchTarget),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? l.reactionShowLess : l.reactionShowAll,
                    style: AppType.callout(
                        weight: FontWeight.w600,
                        color: AppAccessibility.accentText(context)),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
