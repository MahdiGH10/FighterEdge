/// Text folding shared by the banned-advice validator and the copy lint, so
/// both see "Sweat-Suit", "sweat   suit" and "SWEATSUIT" the same way.
///
/// Pure Dart: no clock, no platform, no network.
library;

const Map<String, String> _fold = {
  'ä': 'a',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'ö': 'o',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ü': 'u',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ç': 'c',
  'ñ': 'n',
  'ß': 'ss',
};

/// Characters that render as nothing but split a word for a naive matcher.
final RegExp _invisible = RegExp('[­​-‏⁠﻿]');
final RegExp _apostrophes = RegExp("['‘’ʼ`]");
final RegExp _nonAlnum = RegExp(r'[^a-z0-9]+');

/// Lower-cased, accent-folded text with every run of other characters
/// collapsed to one space and padded by a space on both ends, so a pattern
/// can anchor on whole words with a leading and trailing space.
///
/// Apostrophes are dropped, not turned into spaces: "don't" becomes "dont".
String normalizeForScan(String text) {
  final lower = text.toLowerCase().replaceAll(_invisible, '');
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_fold[char] ?? char);
  }
  final collapsed = buffer
      .toString()
      .replaceAll(_apostrophes, '')
      .replaceAll(_nonAlnum, ' ')
      .trim();
  return ' $collapsed ';
}

const Map<String, String> _leet = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  r'$': 's',
};

/// Letters only, no spaces: catches "s.a.u.n.a" and "sweat_suit". With
/// [deleet] the common digit and symbol substitutions are undone first
/// ("s4un4").
String squashForScan(String text, {bool deleet = false}) {
  final lower = text.toLowerCase().replaceAll(_invisible, '');
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    var char = String.fromCharCode(rune);
    char = _fold[char] ?? char;
    if (deleet) char = _leet[char] ?? char;
    buffer.write(char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z]+'), '');
}
