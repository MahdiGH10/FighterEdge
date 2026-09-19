import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'premium_effects.dart';
import 'press_scale.dart';

/// Standard screen scaffold: dark header with title + optional actions,
/// then a scrollable body. Used by the secondary (non-tab) screens.
class ScreenScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showBack;
  final Widget? floatingActionButton;
  final Widget? bottomNav;
  final bool includeScaffold;
  final bool collapsingHeader;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showBack = false,
    this.floatingActionButton,
    this.bottomNav,
  })  : includeScaffold = true,
        collapsingHeader = false;

  const ScreenScaffold.tab({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  })  : showBack = false,
        floatingActionButton = null,
        bottomNav = null,
        includeScaffold = false,
        collapsingHeader = true;

  @override
  State<ScreenScaffold> createState() => _ScreenScaffoldState();
}

class _ScreenScaffoldState extends State<ScreenScaffold> {
  double _scrollOffset = 0;

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.collapsingHeader ||
        notification.metrics.axis != Axis.vertical ||
        notification.depth > 1) {
      return false;
    }

    final nextOffset = notification.metrics.pixels.clamp(0.0, 80.0);
    if ((nextOffset - _scrollOffset).abs() >= 0.5) {
      setState(() => _scrollOffset = nextOffset);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.collapsingHeader
        ? _CollapsingTabHeader(
            title: widget.title,
            actions: widget.actions,
            scrollOffset: _scrollOffset,
          )
        : AppHeader(
            title: widget.title,
            actions: widget.actions,
            showBack: widget.showBack,
          );
    final content = PremiumBackground(
      child: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: Column(
            children: [
              header,
              Expanded(child: widget.body),
            ],
          ),
        ),
      ),
    );
    if (!widget.includeScaffold && Scaffold.maybeOf(context) != null) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNav,
      body: content,
    );
  }
}

class _CollapsingTabHeader extends StatelessWidget {
  static const _expandedHeight = 96.0;
  static const _collapsedHeight = 56.0;
  static const _collapseDistance = 64.0;

  final String title;
  final List<Widget> actions;
  final double scrollOffset;

  const _CollapsingTabHeader({
    required this.title,
    required this.actions,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (scrollOffset / _collapseDistance).clamp(0.0, 1.0);
    final height =
        _expandedHeight + ((_collapsedHeight - _expandedHeight) * progress);
    final largeOpacity = 1 - progress;
    final compactOpacity = progress;
    final displayTitle = title.toUpperCase();

    return Semantics(
      container: true,
      header: true,
      label: displayTitle,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Stack(
            children: [
              if (compactOpacity > 0.01)
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: _collapsedHeight,
                    child: Center(
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: compactOpacity,
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppAccessibility.adjustStyle(
                              context,
                              AppType.title2(spacing: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (largeOpacity > 0.01)
                Positioned(
                  left: 0,
                  right: actions.isEmpty ? 0 : 56,
                  bottom: Insets.md * (1 - progress),
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: largeOpacity,
                      child: Transform.translate(
                        offset: Offset(0, -8 * progress),
                        child: Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppAccessibility.adjustStyle(
                            context,
                            AppType.largeTitle(spacing: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (actions.isNotEmpty)
                Positioned(
                  top: Insets.xs,
                  right: 0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
            ],
          ),
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
      padding:
          const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
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
              style: AppAccessibility.adjustStyle(
                context,
                AppType.title2(spacing: 1.5),
              ),
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
    return Semantics(
      button: true,
      label: 'Back',
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.9,
        child: SizedBox.square(
          dimension: AppAccessibility.minTouchTarget,
          child: Icon(icon, color: AppColors.textPrimary, size: 26),
        ),
      ),
    );
  }
}

class HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  const HeaderIcon(this.icon, {super.key, this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.9,
        child: SizedBox.square(
          dimension: AppAccessibility.minTouchTarget,
          child: Icon(icon,
              color: AppAccessibility.textSecondary(context), size: 22),
        ),
      ),
    );
  }
}
