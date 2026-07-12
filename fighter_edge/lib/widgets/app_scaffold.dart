import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Standard screen scaffold: dark header with title + optional actions,
/// then a scrollable body. Used by the secondary (non-tab) screens.
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showBack;
  final Widget? floatingActionButton;
  final Widget? bottomNav;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showBack = false,
    this.floatingActionButton,
    this.bottomNav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNav,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(title: title, actions: actions, showBack: showBack),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool showBack;
  const AppHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.md, Insets.lg, Insets.md),
      child: Row(
        children: [
          if (showBack)
            _IconBtn(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTheme.display(18, spacing: 1.5),
            ),
          ),
          if (actions.isEmpty && showBack) const SizedBox(width: 38),
          ...actions,
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: AppColors.textPrimary, size: 26),
      ),
    );
  }
}

class HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const HeaderIcon(this.icon, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}
