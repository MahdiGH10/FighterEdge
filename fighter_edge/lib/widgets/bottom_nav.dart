import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';
import 'press_scale.dart';

class NavItem {
  final IconData icon;

  /// Shown while the tab is selected; the heavier weight of [icon].
  final IconData? activeIcon;
  final String label;
  const NavItem(this.icon, this.label, {this.activeIcon});
}

/// Persistent bottom navigation: a full-width glass bar ([GlassSurface], the
/// navigation layer) that content scrolls under; the home shell extends its
/// body behind it. The selected tab is a filled icon, primary text and a short
/// crimson-to-ember line on the bar's top edge; nothing floats or sits in a
/// pill. At the tinted and solid glass levels the bar keeps the same geometry
/// on a near-opaque or opaque fill.
class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Optional keys, one per item, so something outside the bar (the coach
  /// marks) can find where each tab sits on screen.
  final List<GlobalKey>? itemKeys;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      kind: GlassKind.nav,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: KeyedSubtree(
                  key: itemKeys?[i],
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Primary text when selected, muted otherwise: both clear 4.5:1 on the nav
    // glass at its brightest (see the nav rows of color_contrast_test).
    final color =
        selected ? AppColors.textPrimary : AppAccessibility.textMuted(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: PressScale(
        onTap: onTap,
        haptic: AppHaptics.selection,
        pressedScale: 0.94,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(
                  Insets.xs, Insets.sm, Insets.xs, Insets.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 24,
                    color: color,
                  ),
                  const SizedBox(height: Insets.xxs),
                  SizedBox(
                    height: Insets.md + Insets.xxs,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: AppAccessibility.adjustStyle(
                          context,
                          AppType.micro(
                            weight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : MotionTokens.fast,
              // Not the spring: an overshoot would push the width below zero.
              curve: MotionTokens.count,
              width: selected ? 24 : 0,
              height: 2,
              decoration: const BoxDecoration(
                gradient: AppColors.progressRamp,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
