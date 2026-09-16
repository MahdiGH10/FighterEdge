import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/technique.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';

class TechniqueLibraryScreen extends StatefulWidget {
  final bool embedded;
  const TechniqueLibraryScreen({super.key, this.embedded = false});

  @override
  State<TechniqueLibraryScreen> createState() => _TechniqueLibraryScreenState();
}

class _TechniqueLibraryScreenState extends State<TechniqueLibraryScreen> {
  int _filter = 1; // "Striking" selected like the mockup
  String _query = '';
  final Set<String> _favorites = {};
  final Map<String, int> _progress = {};

  List<Technique> get _visible {
    final discipline = MockData.disciplines[_filter];
    return MockData.techniques.where((t) {
      final matchesDiscipline =
          discipline == 'All' || t.discipline == discipline;
      final matchesQuery = _query.isEmpty ||
          t.title.toLowerCase().contains(_query.toLowerCase()) ||
          t.category.toLowerCase().contains(_query.toLowerCase());
      return matchesDiscipline && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: _SearchField(onChanged: (v) => setState(() => _query = v)),
        ),
        const SizedBox(height: Insets.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: FilterChips(
            options: MockData.disciplines,
            selectedIndex: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Expanded(
          child: _visible.isEmpty
              ? Center(
                  child: Text('No techniques found',
                      style: AppType.callout(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.lg, 0, Insets.lg, Insets.xxl),
                  itemCount: _visible.length,
                  itemBuilder: (_, i) {
                    final technique = _visible[i];
                    return _TechniqueCard(
                      technique,
                      favorite: _favorites.contains(technique.id),
                      progress: _progress[technique.id] ?? 0,
                      onFavorite: () => setState(() {
                        if (!_favorites.remove(technique.id)) {
                          _favorites.add(technique.id);
                        }
                      }),
                      onOpen: () => _openTechnique(technique),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              title: 'Technique Library',
              actions: [HeaderIcon(Icons.search, onTap: () {})],
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Future<void> _openTechnique(Technique technique) async {
    final current = _progress[technique.id] ?? 0;
    final next = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(technique.title, style: AppType.title1()),
            const SizedBox(height: Insets.xs),
            Text('${technique.category} · ${technique.videoCount} lessons',
                style: AppType.subhead(color: AppColors.textSecondary)),
            const SizedBox(height: Insets.lg),
            AppCard(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill,
                      color: AppColors.primary, size: 36),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'Video playback unlocks once real sources are connected.',
                      style: AppType.subhead(
                          weight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(technique.focus,
                style: AppType.callout(color: AppColors.textPrimary)),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: _ProgressButton(
                    label: 'Studied',
                    selected: current >= 1,
                    onTap: () => Navigator.pop(ctx, 1),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _ProgressButton(
                    label: 'Drilled',
                    selected: current >= 2,
                    onTap: () => Navigator.pop(ctx, 2),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _ProgressButton(
                    label: 'Sharp',
                    selected: current >= 3,
                    onTap: () => Navigator.pop(ctx, 3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (next != null) setState(() => _progress[technique.id] = next);
  }
}

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
        hintText: 'Search techniques',
        hintStyle: AppType.callout(color: AppColors.textMuted),
        prefixIcon:
            const Icon(Icons.search, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  final Technique t;
  final bool favorite;
  final int progress;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  const _TechniqueCard(
    this.t, {
    required this.favorite,
    required this.progress,
    required this.onFavorite,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        onTap: onOpen,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF23232A), Color(0xFF141416)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.sports_mma,
                  color: AppColors.textSecondary, size: 26),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.category,
                      style: AppType.micro(
                          weight: FontWeight.w700,
                          color: AppColors.accentText,
                          spacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(t.title,
                      style: AppType.callout(weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${t.videoCount} videos',
                      style: AppType.subhead(
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: Insets.sm),
                  LinearProgressIndicator(
                    value: (progress / 3).clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: AppColors.track,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.positive),
                  ),
                ],
              ),
            ),
            HeaderIcon(
              favorite ? Icons.bookmark : Icons.bookmark_border,
              onTap: onFavorite,
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ProgressButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.positive : AppColors.textPrimary,
        side:
            BorderSide(color: selected ? AppColors.positive : AppColors.border),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
