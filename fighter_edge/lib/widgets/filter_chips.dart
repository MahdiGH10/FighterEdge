import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// Pill selector (filter chips / segmented tabs).
///
/// Three layouts, and none of them may hide an option without saying so:
/// - [scrollable] (the default): one row that scrolls sideways when it
///   overflows. The selected chip is scrolled into view, and a faded edge
///   shows there is more.
/// - `scrollable: false`: one row of equal-width chips.
/// - [columns]: a grid, for a short fixed set whose labels are too long to
///   share one row.
///
/// At large text sizes the non-scrolling layouts wrap onto more lines rather
/// than truncating labels or pushing options off-screen.
class FilterChips extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool scrollable;
  final int? columns;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.scrollable = true,
    this.columns,
  }) : assert(columns == null || columns > 0);

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (int i = 0; i < options.length; i++)
        _Chip(
          label: options[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
        ),
    ];
    final columns = this.columns;

    if (columns == null && scrollable) {
      return _ScrollingChips(selectedIndex: selectedIndex, chips: chips);
    }
    if (AppAccessibility.isLargeText(context)) {
      return Wrap(spacing: Insets.sm, runSpacing: Insets.sm, children: chips);
    }
    if (columns == null) {
      return Row(children: _spaced(chips));
    }
    return Column(
      children: [
        for (int start = 0; start < chips.length; start += columns) ...[
          if (start > 0) const SizedBox(height: Insets.sm),
          Row(
            children: _spaced([
              for (int i = start; i < start + columns; i++)
                i < chips.length ? chips[i] : const SizedBox.shrink(),
            ]),
          ),
        ],
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> children) => [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: Insets.sm),
          Expanded(child: children[i]),
        ],
      ];
}

/// One scrolling row that keeps the selected chip on screen and fades the
/// edge that has more chips behind it.
class _ScrollingChips extends StatefulWidget {
  final int selectedIndex;
  final List<Widget> chips;
  const _ScrollingChips({required this.selectedIndex, required this.chips});

  @override
  State<_ScrollingChips> createState() => _ScrollingChipsState();
}

class _ScrollingChipsState extends State<_ScrollingChips> {
  final _controller = ScrollController();
  late List<GlobalKey> _keys;
  bool _moreBefore = false;
  bool _moreAfter = false;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.chips.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealSelected(animate: false);
      _updateEdges();
    });
  }

  @override
  void didUpdateWidget(_ScrollingChips old) {
    super.didUpdateWidget(old);
    if (widget.chips.length != _keys.length) {
      _keys = List.generate(widget.chips.length, (_) => GlobalKey());
    }
    if (widget.selectedIndex != old.selectedIndex) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _revealSelected(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls only this row — `Scrollable.ensureVisible` would also scroll
  /// the page the row sits in.
  void _revealSelected({required bool animate}) {
    final i = widget.selectedIndex;
    if (!mounted || !_controller.hasClients || i < 0 || i >= _keys.length) {
      return;
    }
    final box = _keys[i].currentContext?.findRenderObject();
    if (box == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _controller.position;
    final start = viewport.getOffsetToReveal(box, 0).offset;
    final end = viewport.getOffsetToReveal(box, 1).offset;
    // Already fully visible: leave the row where the user put it.
    if (position.pixels <= start && position.pixels >= end) return;
    final target = (position.pixels > start ? start : end)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target,
          duration: MotionTokens.standard, curve: MotionTokens.settle);
    }
  }

  void _updateEdges() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final before = p.pixels > p.minScrollExtent + 0.5;
    final after = p.pixels < p.maxScrollExtent - 0.5;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < widget.chips.length; i++)
            Padding(
              key: _keys[i],
              padding: EdgeInsets.only(
                  right: i == widget.chips.length - 1 ? 0 : Insets.sm),
              child: widget.chips[i],
            ),
        ],
      ),
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _updateEdges();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _updateEdges();
          return false;
        },
        // Always masked, even with nothing to fade: swapping the mask in and
        // out would rebuild the scroll view and throw away its position.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            // A fixed-width fade, whatever the row's width.
            final fade = (Insets.xxl / bounds.width).clamp(0.0, 0.5);
            return LinearGradient(
              colors: [
                _moreBefore ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                _moreAfter ? Colors.transparent : Colors.white,
              ],
              stops: [0, fade, 1 - fade, 1],
            ).createShader(bounds);
          },
          child: row,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressScale(
        onTap: onTap,
        // Moving between filters commits nothing — it deserves the lightest
        // tick, not the impact a button gets.
        haptic: AppHaptics.selection,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : MotionTokens.fast,
          curve: MotionTokens.snap,
          // The app's most-used segmented control had no floor at all — text
          // plus padding alone landed around 37px, well under the target.
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          decoration: BoxDecoration(
            // primaryDark, not primary: white 13 pt text on primary is
            // 4.31:1, under WCAG AA. On primaryDark it is 5.76:1 — and the
            // selected chip no longer competes with the screen's one primary
            // button, which keeps the brighter red.
            color: selected ? AppColors.primaryDark : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBright.withValues(alpha: .48)
                  : AppAccessibility.border(context),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm + 2),
          child: Center(
            widthFactor: 1,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppAccessibility.adjustStyle(
                  context,
                  AppType.subhead(
                    weight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppAccessibility.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
