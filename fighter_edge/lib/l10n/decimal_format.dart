import 'package:intl/intl.dart';

/// [value] with exactly [decimals] digits, using [locale]'s own decimal
/// separator ('.' in English, ',' in German, ...).
///
/// `double.toStringAsFixed` always uses '.', which reads as a thousands
/// separator to a German-locale athlete ("79.5" looks like "79,5" does to an
/// English reader, i.e. wrong). Use this wherever a fixed-decimal number
/// reaches the screen; [decimals] stays fixed the same way `toStringAsFixed`
/// does (never dropped for a whole number), only the separator changes.
String formatFixedDecimal(double value, String locale, {int decimals = 1}) =>
    NumberFormat(decimals == 0 ? '0' : '0.${'0' * decimals}', locale)
        .format(value);
