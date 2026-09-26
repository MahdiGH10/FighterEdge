import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../data/recipe_photos.dart';

/// A recipe's photo, filling its box. Decorative: the recipe title beside or
/// above it already names the dish, so screen readers skip it.
class RecipePhotoImage extends StatelessWidget {
  final RecipePhoto photo;

  /// The widest the photo is drawn, in logical pixels. The image is decoded
  /// at this size rather than its full resolution.
  final double displayWidth;

  const RecipePhotoImage(this.photo, {super.key, required this.displayWidth});

  @override
  Widget build(BuildContext context) {
    final pixels =
        (displayWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      photo.assetPath,
      fit: BoxFit.cover,
      cacheWidth: pixels > 0 ? pixels : null,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      // A missing or corrupt asset leaves a quiet surface, never a broken
      // image glyph.
      errorBuilder: (_, __, ___) =>
          const ColoredBox(color: AppColors.surfaceAlt),
    );
  }
}
