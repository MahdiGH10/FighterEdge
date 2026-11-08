import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/recipe_catalog_repository.dart';
import '../../domain/policies/recipe_publication_gate.dart';

/// Tells its [builder] whether the catalog has any recipe the app may show.
///
/// Recipes stay hidden until a named reviewer has signed them off
/// (`RecipePublicationGate`). While none is published, a button or card that
/// points at the library only leads to an empty page, so promotions use this
/// to stay out of the way. The answer is `false` until the catalog has loaded
/// and after any load error, so a dead end never flashes on screen.
class RecipesAvailable extends StatefulWidget {
  const RecipesAvailable({super.key, required this.builder});

  final Widget Function(BuildContext context, bool available) builder;

  @override
  State<RecipesAvailable> createState() => _RecipesAvailableState();
}

class _RecipesAvailableState extends State<RecipesAvailable> {
  bool _available = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(context.read<RecipeCatalogRepository>());
  }

  Future<void> _load(RecipeCatalogRepository catalog) async {
    try {
      final recipes = await catalog.loadAll();
      final available = RecipePublicationGate.visible(recipes).isNotEmpty;
      if (mounted && available != _available) {
        setState(() => _available = available);
      }
    } catch (e) {
      // Stay hidden: the library screen itself reports load errors.
      debugPrint('RecipesAvailable: catalog not readable: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _available);
}
