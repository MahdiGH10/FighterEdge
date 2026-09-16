import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md, top: Insets.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppAccessibility.adjustStyle(
                context,
                AppType.subhead(
                    weight: FontWeight.w700,
                    color: AppAccessibility.textSecondary(context),
                    spacing: 1.4),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
