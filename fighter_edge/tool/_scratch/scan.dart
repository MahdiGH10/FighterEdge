import 'dart:convert';
import 'dart:io';
import 'package:fighter_edge/features/edge_fuel/domain/validation/banned_advice_validator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/copy_lint.dart';
void main() {
  for (final f in ['en','de']) {
    final m = jsonDecode(File('lib/l10n/app_$f.arb').readAsStringSync(encoding: utf8)) as Map<String,dynamic>;
    m.forEach((k,v){
      if (k.startsWith('@') || v is! String) return;
      final t = BannedAdviceValidator.scan(v); final c = CopyLint.scan(v);
      if (t.isNotEmpty || c.isNotEmpty) print('$f $k: $t $c  :: $v');
    });
  }
}
