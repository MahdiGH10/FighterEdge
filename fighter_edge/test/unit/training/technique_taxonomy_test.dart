import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/drills/drill_catalog.dart';
import 'package:fighter_edge/training/taxonomy/technique_taxonomy.dart';

void main() {
  group('TechniqueTaxonomy', () {
    test('keeps the supplied Striking and Grappling paths intact', () {
      expect(
        TechniqueTaxonomy.systems.map((system) => system.id),
        [
          TechniqueTaxonomy.strikingSystemId,
          TechniqueTaxonomy.grapplingSystemId,
        ],
      );
      expect(
        TechniqueTaxonomy.categoriesForSystem(
          TechniqueTaxonomy.strikingSystemId,
        ),
        hasLength(12),
      );
      expect(
        TechniqueTaxonomy.categoriesForSystem(
          TechniqueTaxonomy.grapplingSystemId,
        ),
        hasLength(10),
      );
    });

    test('uses stable unique IDs and only points at known systems', () {
      final systemIds = TechniqueTaxonomy.systems.map((system) => system.id);
      final categoryIds =
          TechniqueTaxonomy.categories.map((category) => category.id);

      expect(systemIds.toSet(), hasLength(TechniqueTaxonomy.systems.length));
      expect(
        categoryIds.toSet(),
        hasLength(TechniqueTaxonomy.categories.length),
      );
      for (final category in TechniqueTaxonomy.categories) {
        expect(TechniqueTaxonomy.systemById(category.systemId), isNotNull);
        expect(category.techniques, isNotEmpty);
      }
    });

    test('every shipped drill maps to a real coach path', () {
      for (final drill in DrillCatalog.all) {
        final category = TechniqueTaxonomy.categoryById(drill.categoryId);
        expect(category, isNotNull, reason: drill.id);
        expect(
          DrillCatalog.byTaxonomySystem(category!.systemId),
          contains(drill),
          reason: drill.id,
        );
      }
    });

    test('category and system queries never invent a drill', () {
      expect(
        DrillCatalog.byTaxonomyCategory('striking.punches')
            .map((drill) => drill.id),
        ['jab', 'lead_hook'],
      );
      expect(
        DrillCatalog.byTaxonomyCategory('grappling.judo_throws'),
        isEmpty,
        reason: 'A mapped path is not misrepresented as authored content.',
      );
      expect(
        DrillCatalog.byTaxonomySystem(TechniqueTaxonomy.strikingSystemId),
        isNotEmpty,
      );
      expect(
        DrillCatalog.byTaxonomySystem(TechniqueTaxonomy.grapplingSystemId),
        isNotEmpty,
      );
    });
  });
}
