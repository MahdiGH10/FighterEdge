import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/domain/validation/banned_advice_validator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/copy_lint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fuel V2 rules 3 and 6 as a build gate: every string in both ARB files
/// passes [CopyLint.lint], or is on this list with the exact categories it
/// may hit and why. Keep the list short. Prefer rewording a string.
class _Allowed {
  const _Allowed(this.categories, this.reason);

  /// [ToneCategory] and [BannedAdviceCategory] values this key may hit.
  final Set<Enum> categories;
  final String reason;
}

const _supervisedWaterCut = _Allowed(
  {BannedAdviceCategory.fluidRestriction},
  'Names a water cut only to say it needs a coach or dietitian and that the '
  'app does not plan it.',
);

const Map<String, _Allowed> _allowlist = {
  'dashboardStatStreak': _Allowed(
    {ToneCategory.streak},
    'Training streak on the dashboard. Rule 6 bans food-logging streaks only.',
  ),
  'fightPathSupervision': _supervisedWaterCut,
  'fightPathShortSupervision': _supervisedWaterCut,
  'fightWeekSupervision': _supervisedWaterCut,
  'fightWeekWater': _Allowed(
    {BannedAdviceCategory.fluidRestriction},
    'Tells the fighter to drink normally and that the app never plans water '
    'cuts.',
  ),
};

Map<String, String> _strings(String locale) {
  final file = File('lib/l10n/app_$locale.arb');
  final json = jsonDecode(file.readAsStringSync(encoding: utf8)) as Map;
  return {
    for (final entry in json.entries)
      if (!(entry.key as String).startsWith('@') && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

Set<Enum> _hits(String text) {
  final report = CopyLint.lint(text);
  return {
    for (final v in report.tone) v.category,
    for (final m in report.bannedAdvice) m.category,
  };
}

void main() {
  const locales = ['en', 'de'];

  for (final locale in locales) {
    test('app_$locale.arb has no banned advice or banned tone words', () {
      final strings = _strings(locale);
      expect(strings.length, greaterThan(100));
      final failures = <String>[];
      strings.forEach((key, value) {
        final report = CopyLint.lint(value);
        if (report.isClean) return;
        final allowed = _allowlist[key]?.categories ?? const <Enum>{};
        final unexpected = _hits(value).difference(allowed);
        if (unexpected.isNotEmpty) failures.add('$key: $report');
      });
      expect(failures, isEmpty,
          reason: 'Reword these strings (Fuel V2 rules 3 and 6), or add the '
              'key to the allowlist in this test with a reason.');
    });
  }

  test('every allowlisted key exists and still needs its exception', () {
    final all = {for (final l in locales) l: _strings(l)};
    for (final entry in _allowlist.entries) {
      expect(entry.value.reason, isNotEmpty);
      for (final locale in locales) {
        expect(all[locale], contains(entry.key), reason: '$locale lacks it');
      }
      final hits = {
        for (final locale in locales) ..._hits(all[locale]![entry.key]!),
      };
      expect(hits.intersection(entry.value.categories), isNotEmpty,
          reason: '${entry.key} no longer hits the lint: drop it from the '
              'allowlist');
    }
  });
}
