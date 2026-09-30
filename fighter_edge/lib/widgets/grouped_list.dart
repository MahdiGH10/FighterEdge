import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';
import 'stat_card.dart';

/// A single surface for related rows, separated by accessible hairlines.
/// Children own their padding, so compound rows can keep their existing actions.
class GroupedList extends StatelessWidget {
  final List<Widget> children;
  const GroupedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Divider(
                  height: Insets.hairline,
                  thickness: Insets.hairline,
                  color: AppAccessibility.border(context)),
            child,
          ],
        ]),
      );
}

/// A readable row with optional identifying glyph and a quiet accessory.
/// Accessories stack under the text at large sizes; labels never truncate.
class GroupedRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  const GroupedRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final large = AppAccessibility.isLargeText(context);
    final content = Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading != null) ...[leading!, const SizedBox(width: Insets.md)],
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppType.callout(weight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xs),
            Text(subtitle!,
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
          ],
          if (large && trailing != null) ...[
            const SizedBox(height: Insets.sm),
            trailing!,
          ],
        ])),
        if (!large && trailing != null) ...[
          const SizedBox(width: Insets.md),
          trailing!
        ],
        if (onTap != null) ...[
          const SizedBox(width: Insets.sm),
          const Icon(AppIcons.caretRight,
              color: AppColors.textMuted, size: IconSizes.row),
        ],
      ]),
    );
    return ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
      child: onTap == null
          ? Semantics(container: true, child: content)
          : Semantics(
              button: true, child: PressScale(onTap: onTap, child: content)),
    );
  }
}
