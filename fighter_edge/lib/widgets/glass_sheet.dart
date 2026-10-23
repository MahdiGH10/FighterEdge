import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Shows a bottom sheet on glass: [GlassSurface] (blur at the full level, a
/// near-opaque tint at the tinted level, a solid surface at the solid level),
/// 24px top corners, a grabber and the V2 scrim.
///
/// Use this instead of a bare `showModalBottomSheet`, which paints a flat
/// Material surface. A sheet is one of the (at most three) blurs on a screen,
/// so open one sheet at a time and never put a [GlassSurface] inside it.
///
/// Do not use it for a `DraggableScrollableSheet`: that widget fills the whole
/// modal height whatever the sheet's visible size, so the glass would cover the
/// screen. Give those a solid [AppColors.surfaceElevated] sheet with
/// [sheetShape] instead.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    backgroundColor: AppColors.transparent,
    elevation: 0,
    barrierColor: GlassColors.sheetScrim,
    shape: sheetShape,
    builder: (sheetContext) => GlassSurface(
      kind: GlassKind.sheet,
      borderRadius: sheetRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDragHandle) const _Grabber(),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

/// The top corners of every sheet.
const sheetRadius = BorderRadius.vertical(top: Radius.circular(Radii.sheet));

/// [sheetRadius] as a shape, for a sheet that is not on glass.
const sheetShape = RoundedRectangleBorder(borderRadius: sheetRadius);

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.only(top: Insets.sm, bottom: Insets.xs),
        child: Center(
          child: SizedBox(
            width: 38,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: GlassColors.sheetGrabber,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
