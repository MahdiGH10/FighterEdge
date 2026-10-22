/// Text folding shared by the banned-advice validator and the copy lint, so
/// both see "Sweat-Suit", "sweat   suit", "SWEATSUIT", "Saúna", "s.a.u.n.a"
/// and "s4una" the same way.
///
/// Pure Dart: no clock, no platform, no network.
library;

/// Accented and look-alike letters, folded to plain ASCII. The Cyrillic and
/// Greek entries are the letters that look identical to Latin ones, the
/// usual way to slip a word past a filter.
const Map<String, String> _fold = {
  // Latin with accents.
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
  'ğ': 'g',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
  'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ő': 'o', 'œ': 'oe',
  'ř': 'r',
  'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss',
  'ť': 't', 'ţ': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ž': 'z', 'ż': 'z',
  // Cyrillic look-alikes.
  'а': 'a', 'в': 'b', 'е': 'e', 'ё': 'e', 'к': 'k', 'м': 'm', 'н': 'h',
  'о': 'o', 'р': 'p', 'с': 'c', 'т': 't', 'у': 'y', 'х': 'x', 'і': 'i',
  'ј': 'j', 'ѕ': 's',
  // Greek look-alikes.
  'α': 'a', 'ε': 'e', 'ι': 'i', 'κ': 'k', 'ν': 'v', 'ο': 'o', 'ρ': 'p',
  'τ': 't', 'υ': 'u', 'χ': 'x',
};

/// Digit and symbol stand-ins for letters ("s4una", "f@sting").
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

/// Characters that render as nothing but split a word for a naive matcher:
/// soft hyphen, zero-width space and joiners, direction marks, word joiner
/// and the byte-order mark.
final RegExp _invisible = RegExp('[­​-‏⁠﻿]');
final RegExp _apostrophes = RegExp("['‘’ʼ`]");
final RegExp _nonAlnum = RegExp(r'[^a-z0-9]+');
final RegExp _nonAlpha = RegExp(r'[^a-z]+');

/// A run of letters, digits and leet symbols holding at least one letter,
/// so "s4una" is decoded but "2300" and the 5 in "5 days" are not.
final RegExp _leetToken = RegExp(r'[a-z0-9@$]*[a-z][a-z0-9@$]*');

/// Three or more single letters in a row: "s a u n a" from "s.a.u.n.a".
final RegExp _spacedLetters = RegExp(r'\b(?:[a-z] ){2,}[a-z]\b');

/// Lower case, invisible characters removed, full-width and accented
/// letters folded to ASCII, apostrophes dropped.
String _foldText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.replaceAll(_invisible, '').runes) {
    // Full-width ASCII (U+FF01 to U+FF5E) back to ASCII.
    final ascii = rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune;
    final char = String.fromCharCode(ascii).toLowerCase();
    buffer.write(_fold[char] ?? char);
  }
  return buffer.toString().replaceAll(_apostrophes, '');
}

String _deleetChars(String text) =>
    text.split('').map((c) => _leet[c] ?? c).join();

/// Lower-cased, accent-folded text with every run of other characters
/// collapsed to one space and padded by a space on both ends, so a pattern
/// can anchor on whole words.
///
/// Apostrophes are dropped, not turned into spaces: "don't" becomes "dont".
/// Runs of three or more single letters are joined back into one word, so
/// "s.a.u.n.a" reads as "sauna". With [deleet], digits and symbols inside a
/// word are read as the letters they stand for ("s4una" becomes "sauna");
/// plain numbers are left alone.
String normalizeForScan(String text, {bool deleet = false}) {
  var folded = _foldText(text);
  if (deleet) {
    folded = folded.replaceAllMapped(_leetToken, (m) => _deleetChars(m[0]!));
  }
  final collapsed = folded.replaceAll(_nonAlnum, ' ').trim();
  final joined = collapsed.replaceAllMapped(
    _spacedLetters,
    (m) => m[0]!.replaceAll(' ', ''),
  );
  return ' $joined ';
}

/// Letters only, no spaces: catches "sau na" and "sweat_suit". With [deleet]
/// the common digit and symbol substitutions are undone first ("s4un4").
///
/// Joining words can create a match that spans two of them, so match only
/// long, unambiguous tokens against this form.
String squashForScan(String text, {bool deleet = false}) {
  var folded = _foldText(text);
  if (deleet) folded = _deleetChars(folded);
  return folded.replaceAll(_nonAlpha, '');
}
