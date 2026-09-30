import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/recipe_photos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recipes = (jsonDecode(
    File('assets/data/edge_fuel_recipes_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>)['recipes'] as List<dynamic>;
  final recipeIds = {for (final r in recipes) (r as Map)['id'] as String};

  test('every shipped recipe has a credited photo', () {
    expect(recipePhotos.keys.toSet(), recipeIds);
  });

  test('every credit names an author, an open licence and its source', () {
    for (final photo in recipePhotos.values) {
      expect(photo.recipeId, isNotEmpty);
      expect(recipePhotos[photo.recipeId], same(photo));
      expect(photo.author.trim(), isNotEmpty, reason: photo.recipeId);
      expect(
        photo.license,
        anyOf('Public domain', 'CC0', matches(RegExp(r'^CC BY \d\.\d$'))),
        reason: '${photo.recipeId}: only licences that allow a paid app',
      );
      final source = Uri.parse(photo.sourceUrl);
      expect(source.scheme, 'https', reason: photo.recipeId);
      expect(source.host, isNotEmpty, reason: photo.recipeId);
    }
  });

  test('every photo file is credited, present and small', () {
    final files = Directory('assets/images/recipes')
        .listSync()
        .whereType<File>()
        .toList();
    final fileIds = {
      for (final f in files)
        f.uri.pathSegments.last.replaceAll(RegExp(r'\.webp$'), ''),
    };
    expect(fileIds, recipePhotos.keys.toSet());
    for (final photo in recipePhotos.values) {
      final file = File(photo.assetPath);
      expect(file.existsSync(), isTrue, reason: photo.assetPath);
      expect(file.lengthSync(), lessThan(150 * 1024), reason: photo.assetPath);
    }
  });

  test('the credit line shows author and licence', () {
    const photo = RecipePhoto(
      recipeId: 'x',
      author: 'Ana',
      license: 'CC BY 2.0',
      sourceUrl: 'https://example.com/x',
    );
    expect(photo.credit, 'Ana · CC BY 2.0');
    expect(photo.assetPath, 'assets/images/recipes/x.webp');
  });
}
