import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

class NavItem {
  final IconData icon;

  /// Shown while the tab is selected; the heavier weight of [icon].
  final IconData? activeIcon;
  final String label;
  const NavItem(this.icon, this.label, {this.activeIcon});
}

/// Persistent bottom navigation: a flat, full-width bar on the screen
/// background, separated by a hairline. The selected tab is a filled icon, the
/// accent colour and a short line on the bar's top edge; nothing floats, blurs
/// or sits in a pill.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        border: Border(
          top: BorderSide(color: AppAccessibility.border(context)),
        ),
      ),
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
    // accentText rather than primary: the label is 11pt, and small accent text
    // needs the brighter tone to clear AA on this surface.
    final color = selected
        ? AppAccessibility.accentText(context)
        : AppAccessibility.textMuted(context);
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
              width: selected ? 28 : 0,
              height: 2,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
