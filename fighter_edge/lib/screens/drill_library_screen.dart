import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/drills/drill.dart';
import '../training/drills/drill_catalog.dart';
import '../training/drills/drill_progress_store.dart';
import '../training/taxonomy/technique_taxonomy.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import 'paywall_screen.dart';

/// Coach-mapped technique paths and written drills, embedded in the Train tab.
///
/// Every drill is complete in text — key points, common mistakes, and how to
/// put reps on it — so the library is useful today without video. Progress
/// (studied → drilled → sharp) and bookmarks are the athlete's own log.
class DrillLibraryScreen extends StatefulWidget {
  const DrillLibraryScreen({super.key});

  @override
  State<DrillLibraryScreen> createState() => _DrillLibraryScreenState();
}

class _DrillLibraryScreenState extends State<DrillLibraryScreen> {
  static const _savedFilter = 'Saved';

  late final DrillProgressStore _store;
  String? _selectedSystemId;
  String? _selectedCategoryId;
  bool _savedOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _store = DrillProgressStore(
      userId: context.read<AuthController>().user?.id,
    )..load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  List<String> get _options => [
        'All',
        ...TechniqueTaxonomy.systems.map((system) => system.title),
        _savedFilter,
      ];

  int get _selectedOptionIndex {
    if (_savedOnly) return _options.length - 1;
    if (_selectedSystemId == null) return 0;
    final systemIndex =
        TechniqueTaxonomy.systems.indexWhere((s) => s.id == _selectedSystemId);
    return systemIndex < 0 ? 0 : systemIndex + 1;
  }

  TechniqueSystem? get _selectedSystem => _selectedSystemId == null
      ? null
      : TechniqueTaxonomy.systemById(_selectedSystemId!);

  TechniqueCategory? get _selectedCategory => _selectedCategoryId == null
      ? null
      : TechniqueTaxonomy.categoryById(_selectedCategoryId!);

  List<Drill> get _visible {
    final query = _query.trim().toLowerCase();
    final source = _selectedCategoryId != null
        ? DrillCatalog.byTaxonomyCategory(_selectedCategoryId)
        : DrillCatalog.byTaxonomySystem(_selectedSystemId);
    return source.where((drill) {
      if (_savedOnly && !_store.isBookmarked(drill.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      return drill.title.toLowerCase().contains(query) ||
          drill.sport.toLowerCase().contains(query) ||
          drill.summary.toLowerCase().contains(query);
    }).toList();
  }

  void _selectPrimaryFilter(int index) {
    setState(() {
      if (index == 0) {
        _selectedSystemId = null;
        _selectedCategoryId = null;
        _savedOnly = false;
        return;
      }
      if (index == _options.length - 1) {
        _selectedSystemId = null;
        _selectedCategoryId = null;
        _savedOnly = true;
        return;
      }
      _selectedSystemId = TechniqueTaxonomy.systems[index - 1].id;
      _selectedCategoryId = null;
      _savedOnly = false;
    });
  }

  void _selectSystem(String systemId) {
    setState(() {
      _selectedSystemId = systemId;
      _selectedCategoryId = null;
      _savedOnly = false;
    });
  }

  void _selectCategory(TechniqueCategory category) {
    setState(() {
      final isSelected = _selectedCategoryId == category.id;
      _selectedSystemId = category.systemId;
      _selectedCategoryId = isSelected ? null : category.id;
      _savedOnly = false;
    });
  }

  void _openPaywall() => AppNavigation.push(
        context,
        AppRoutes.paywall,
        extra: Feature.fullTechniqueLibrary,
        fallbackBuilder: (_) =>
            const PaywallScreen(highlight: Feature.fullTechniqueLibrary),
      );

  @override
  Widget build(BuildContext context) {
    final isPro =
        context.watch<AuthController>().allows(Feature.fullTechniqueLibrary);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        // A free account sees what it can open first, rather than hunting
        // for the starters between locks.
        final visible = isPro
            ? _visible
            : [
                ..._visible.where((d) => d.starter),
                ..._visible.where((d) => !d.starter),
              ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _SearchField(
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: Insets.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: FilterChips(
                options: _options,
                selectedIndex: _selectedOptionIndex,
                onSelected: _selectPrimaryFilter,
              ),
            ),
            const SizedBox(height: Insets.md),
            if (!_savedOnly) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.lg),
                child: _SectionLabel('EXPLORE TECHNIQUE PATHS'),
              ),
              _TechniquePathRail(
                selectedSystem: _selectedSystem,
                selectedCategoryId: _selectedCategoryId,
                onSelectSystem: _selectSystem,
                onSelectCategory: _selectCategory,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (_selectedCategory case final category?) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                child: _SelectedPathSummary(
                  category: category,
                  onClear: () => setState(() => _selectedCategoryId = null),
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Text(
                '${_store.sharpCount} of ${DrillCatalog.all.length} drills '
                'sharp',
                style: AppType.subhead(
                  weight: FontWeight.w600,
                  color: AppAccessibility.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: visible.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(Insets.lg),
                      children: [
                        _savedOnly && _query.trim().isEmpty
                            ? const EmptyState(
                                icon: Icons.bookmark_border,
                                title: 'No saved drills yet',
                                message: 'Tap the bookmark on any drill to '
                                    'keep it here for your next session.',
                              )
                            : _selectedCategory != null && _query.trim().isEmpty
                                ? _CurriculumOnlyState(
                                    category: _selectedCategory!,
                                  )
                                : const EmptyState(
                                    icon: Icons.search_off,
                                    title: 'No drills match',
                                    message:
                                        'Try a different word or clear the '
                                        'filter.',
                                  ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.lg, 0, Insets.lg, Insets.xxl),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final drill = visible[i];
                        final locked = !isPro && !drill.starter;
                        return _DrillCard(
                          drill: drill,
                          locked: locked,
                          progress: _store.progressOf(drill.id),
                          bookmarked: _store.isBookmarked(drill.id),
                          onBookmark: () {
                            AppHaptics.selection();
                            _store.toggleBookmark(drill.id);
                          },
                          onOpen: () =>
                              locked ? _showLocked(drill) : _showDrill(drill),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDrill(Drill drill) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (context, controller) => ListenableBuilder(
          listenable: _store,
          builder: (context, _) => _DrillDetail(
            drill: drill,
            controller: controller,
            progress: _store.progressOf(drill.id),
            onProgress: (p) {
              if (p == DrillProgress.sharp) {
                AppHaptics.success();
              } else {
                AppHaptics.commit();
              }
              _store.setProgress(drill.id, p);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showLocked(Drill drill) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DrillMeta(drill: drill),
              const SizedBox(height: Insets.xs),
              Text(drill.title, style: AppType.largeTitle()),
              const SizedBox(height: Insets.sm),
              Text(
                drill.summary,
                style: AppType.body(
                    color: AppAccessibility.textSecondary(sheetContext)),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                'Pro unlocks all ${DrillCatalog.all.length} drills — key '
                'points, common mistakes, and a round-by-round way to drill '
                'each one.',
                style: AppType.callout(
                    color: AppAccessibility.textSecondary(sheetContext)),
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                'Unlock the full library',
                icon: Icons.lock_open_outlined,
                expand: true,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openPaywall();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact two-step navigator for the coach-owned taxonomy. Systems are the
/// first level; selecting one replaces them with its paths. This keeps the
/// Train screen one-handed and avoids a 22-item filter row.
class _TechniquePathRail extends StatelessWidget {
  final TechniqueSystem? selectedSystem;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelectSystem;
  final ValueChanged<TechniqueCategory> onSelectCategory;

  const _TechniquePathRail({
    required this.selectedSystem,
    required this.selectedCategoryId,
    required this.onSelectSystem,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final categories = selectedSystem == null
        ? null
        : TechniqueTaxonomy.categoriesForSystem(selectedSystem!.id);
    // At large accessibility text sizes the cards grow vertically instead of
    // clipping their labels or shrinking the athlete's type back down.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final railHeight = 126 + ((textScale - 1).clamp(0.0, 1.4).toDouble() * 112);

    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        key: ValueKey('technique-paths-${selectedSystem?.id ?? 'systems'}'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        itemCount: categories?.length ?? TechniqueTaxonomy.systems.length,
        separatorBuilder: (context, index) => const SizedBox(width: Insets.sm),
        itemBuilder: (context, index) {
          // Keep the list builder allocation-free apart from the visible
          // cards. The taxonomy itself is static, bundled data.
          return selectedSystem == null
              ? _TechniqueSystemCard(
                  system: TechniqueTaxonomy.systems[index],
                  onTap: () => onSelectSystem(
                    TechniqueTaxonomy.systems[index].id,
                  ),
                )
              : _TechniqueCategoryCard(
                  category: categories![index],
                  selected: categories[index].id == selectedCategoryId,
                  onTap: () => onSelectCategory(categories[index]),
                );
        },
      ),
    );
  }
}

class _TechniqueSystemCard extends StatelessWidget {
  final TechniqueSystem system;
  final VoidCallback onTap;

  const _TechniqueSystemCard({required this.system, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryCount =
        TechniqueTaxonomy.categoriesForSystem(system.id).length;
    final secondary = AppAccessibility.textSecondary(context);
    final icon = system.id == TechniqueTaxonomy.strikingSystemId
        ? Icons.sports_mma_outlined
        : Icons.sports_kabaddi_outlined;
    return SizedBox(
      width: 216,
      child: Semantics(
        button: true,
        label: '${system.title}, $categoryCount technique paths',
        child: ExcludeSemantics(
          child: AppCard(
            key: ValueKey('training-system-${system.id}'),
            onTap: onTap,
            accent: AppColors.primary,
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary, size: IconSizes.row),
                const SizedBox(height: Insets.sm),
                Text(system.title, style: AppType.headline()),
                const SizedBox(height: Insets.xxs),
                Expanded(
                  child: Text(
                    system.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.micro(color: secondary),
                  ),
                ),
                Text(
                  '$categoryCount technique paths',
                  style: AppType.micro(
                    weight: FontWeight.w700,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechniqueCategoryCard extends StatelessWidget {
  final TechniqueCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _TechniqueCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final writtenDrillCount =
        DrillCatalog.byTaxonomyCategory(category.id).length;
    final availability = writtenDrillCount == 0
        ? 'Curriculum mapped'
        : '$writtenDrillCount written ${writtenDrillCount == 1 ? 'drill' : 'drills'}';
    final secondary = AppAccessibility.textSecondary(context);
    return SizedBox(
      width: 188,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${category.title}, ${category.techniques.length} techniques, $availability',
        child: ExcludeSemantics(
          child: AppCard(
            key: ValueKey('training-category-${category.id}'),
            onTap: onTap,
            accent: selected ? AppColors.primary : null,
            color: selected ? AppColors.primarySoft : null,
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline(
                    color: selected ? AppColors.accentText : null,
                  ),
                ),
                const SizedBox(height: Insets.xxs),
                Expanded(
                  child: Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.micro(color: secondary),
                  ),
                ),
                Text(
                  availability,
                  style: AppType.micro(
                    weight: FontWeight.w700,
                    color: selected
                        ? AppColors.accentText
                        : AppAccessibility.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedPathSummary extends StatelessWidget {
  final TechniqueCategory category;
  final VoidCallback onClear;

  const _SelectedPathSummary({
    required this.category,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final system = TechniqueTaxonomy.systemById(category.systemId)!;
    final writtenDrillCount =
        DrillCatalog.byTaxonomyCategory(category.id).length;
    final secondary = AppAccessibility.textSecondary(context);
    return AppCard(
      key: const ValueKey('selected-technique-path'),
      accent: AppColors.primary,
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${system.title} / ${category.title}',
                  style: AppType.headline(color: AppColors.accentText),
                ),
              ),
              Semantics(
                button: true,
                label: 'Clear selected technique path',
                child: TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
          Text(
            category.techniques.join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead(color: secondary),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            writtenDrillCount == 0
                ? 'Coach-mapped curriculum. Written drills are coming.'
                : '$writtenDrillCount written ${writtenDrillCount == 1 ? 'drill' : 'drills'} in this path.',
            style: AppType.micro(
              weight: FontWeight.w700,
              color: AppAccessibility.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumOnlyState extends StatelessWidget {
  final TechniqueCategory category;

  const _CurriculumOnlyState({required this.category});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('curriculum-only-${category.id}'),
      child: EmptyState(
        icon: Icons.menu_book_outlined,
        title: '${category.title} is mapped',
        message: 'The coach\'s curriculum is here. Written drills are being '
            'added to this path.',
      ),
    );
  }
}

IconData _disciplineIcon(DrillDiscipline d) => switch (d) {
      DrillDiscipline.striking => Icons.sports_mma,
      DrillDiscipline.wrestling => Icons.sports_kabaddi,
      DrillDiscipline.bjj => Icons.sports_martial_arts,
      DrillDiscipline.clinch => Icons.front_hand_outlined,
    };

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AppType.callout(),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: 'Search drills',
        hintStyle: AppType.callout(color: AppAccessibility.textMuted(context)),
        prefixIcon: Icon(Icons.search,
            color: AppAccessibility.textMuted(context), size: IconSizes.row),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.zero,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: BorderSide(color: AppAccessibility.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _DrillMeta extends StatelessWidget {
  final Drill drill;
  const _DrillMeta({required this.drill});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${drill.sport} · ${drill.level.label.toUpperCase()} · '
      '${drill.needsPartner ? 'PARTNER' : 'SOLO'}',
      style: AppType.micro(
        weight: FontWeight.w700,
        color: AppAccessibility.accentText(context),
        spacing: .8,
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final Drill drill;
  final bool locked;
  final DrillProgress progress;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onOpen;

  const _DrillCard({
    required this.drill,
    required this.locked,
    required this.progress,
    required this.bookmarked,
    required this.onBookmark,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Semantics(
        button: true,
        label: [
          drill.title,
          drill.summary,
          if (locked) 'Pro' else progress.label,
        ].join(', '),
        child: AppCard(
          onTap: onOpen,
          padding: const EdgeInsets.fromLTRB(
              Insets.md, Insets.md, Insets.xs, Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: IconSizes.badge,
                  height: IconSizes.badge,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Icon(_disciplineIcon(drill.discipline),
                      color: AppColors.primary, size: IconSizes.inline),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DrillMeta(drill: drill),
                      const SizedBox(height: Insets.xxs),
                      Row(
                        children: [
                          Flexible(
                            child: Text(drill.title, style: AppType.headline()),
                          ),
                          if (locked) ...[
                            const SizedBox(width: Insets.xs),
                            const Icon(Icons.lock_outline,
                                size: IconSizes.inline,
                                color: AppColors.premium),
                          ],
                        ],
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        drill.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subhead(color: secondary),
                      ),
                      if (!locked) ...[
                        const SizedBox(height: Insets.sm),
                        _ProgressPips(progress: progress),
                      ],
                    ],
                  ),
                ),
              ),
              _BookmarkButton(bookmarked: bookmarked, onTap: onBookmark),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final bool bookmarked;
  final VoidCallback onTap;
  const _BookmarkButton({required this.bookmarked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: bookmarked,
      label: 'Save drill',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppAccessibility.minTouchTarget / 2,
        child: SizedBox.square(
          dimension: AppAccessibility.minTouchTarget,
          child: Icon(
            bookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: bookmarked
                ? AppColors.accentText
                : AppAccessibility.textMuted(context),
            size: IconSizes.row,
          ),
        ),
      ),
    );
  }
}

/// Three segments — studied, drilled, sharp — so progress reads at a glance
/// without a percentage that would claim more precision than a self-report
/// has.
class _ProgressPips extends StatelessWidget {
  final DrillProgress progress;
  const _ProgressPips({required this.progress});

  @override
  Widget build(BuildContext context) {
    final filled = progress.index;
    final label = Text(
      progress.label,
      style: AppType.micro(
        weight: FontWeight.w700,
        color: filled == 0
            ? AppAccessibility.textMuted(context)
            : AppColors.positive,
      ),
    );
    final pips = Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Expanded(
            child: Container(
              height: Insets.xs,
              decoration: BoxDecoration(
                color: i <= filled ? AppColors.positive : AppColors.track,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: Insets.xs),
        ],
      ],
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4;
    return largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [pips, const SizedBox(height: Insets.xs), label],
          )
        : Row(
            children: [
              Expanded(child: pips),
              const SizedBox(width: Insets.sm),
              label,
            ],
          );
  }
}

class _DrillDetail extends StatelessWidget {
  final Drill drill;
  final ScrollController controller;
  final DrillProgress progress;
  final ValueChanged<DrillProgress> onProgress;

  const _DrillDetail({
    required this.drill,
    required this.controller,
    required this.progress,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
      children: [
        _DrillMeta(drill: drill),
        const SizedBox(height: Insets.xs),
        Text(drill.title, style: AppType.largeTitle()),
        const SizedBox(height: Insets.sm),
        Text(drill.summary, style: AppType.body(color: secondary)),
        const SizedBox(height: Insets.xl),
        const _SectionLabel('KEY POINTS'),
        for (var i = 0; i < drill.keyPoints.length; i++)
          _NumberedPoint(number: i + 1, text: drill.keyPoints[i]),
        const SizedBox(height: Insets.lg),
        const _SectionLabel('COMMON MISTAKES'),
        for (final mistake in drill.commonMistakes)
          _MistakePoint(text: mistake),
        const SizedBox(height: Insets.lg),
        AppCard(
          accent: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('HOW TO DRILL IT'),
              Text(drill.prescription, style: AppType.callout()),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        const _SectionLabel('WHERE ARE YOU WITH IT?'),
        Row(
          children: [
            for (final p in const [
              DrillProgress.studied,
              DrillProgress.drilled,
              DrillProgress.sharp,
            ]) ...[
              Expanded(
                child: _ProgressChoice(
                  progress: p,
                  selected: progress == p,
                  reached: progress.index >= p.index,
                  // Tapping the current level again clears back one step,
                  // so a mis-tap is always undoable.
                  onTap: () => onProgress(
                    progress == p ? DrillProgress.values[p.index - 1] : p,
                  ),
                ),
              ),
              if (p != DrillProgress.sharp) const SizedBox(width: Insets.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        text,
        style: AppType.micro(
          weight: FontWeight.w800,
          color: AppAccessibility.textMuted(context),
          spacing: .8,
        ),
      ),
    );
  }
}

class _NumberedPoint extends StatelessWidget {
  final int number;
  final String text;
  const _NumberedPoint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Insets.xl,
            child: Text('$number',
                style: AppType.title2(color: AppColors.primary)),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: AppType.callout())),
        ],
      ),
    );
  }
}

class _MistakePoint extends StatelessWidget {
  final String text;
  const _MistakePoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close_rounded,
              size: IconSizes.inline, color: AppColors.warning),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: AppType.callout(
                  color: AppAccessibility.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChoice extends StatelessWidget {
  final DrillProgress progress;
  final bool selected;
  final bool reached;
  final VoidCallback onTap;

  const _ProgressChoice({
    required this.progress,
    required this.selected,
    required this.reached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        reached ? AppColors.positive : AppAccessibility.textSecondary(context);
    return Semantics(
      button: true,
      selected: selected,
      label: progress.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.button),
        child: Container(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: reached ? AppColors.positiveSoft : null,
            borderRadius: BorderRadius.circular(Radii.button),
            border: Border.all(
              color: reached
                  ? AppColors.positive
                  : AppAccessibility.border(context),
            ),
          ),
          child: Text(
            progress.label,
            style: AppType.callout(weight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}
