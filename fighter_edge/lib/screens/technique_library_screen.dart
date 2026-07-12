import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/technique.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';

class TechniqueLibraryScreen extends StatefulWidget {
  const TechniqueLibraryScreen({super.key});

  @override
  State<TechniqueLibraryScreen> createState() => _TechniqueLibraryScreenState();
}

class _TechniqueLibraryScreenState extends State<TechniqueLibraryScreen> {
  int _filter = 1; // "Striking" selected like the mockup
  String _query = '';

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
                          style: AppTheme.body(14, color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.lg, 0, Insets.lg, Insets.xxl),
                      itemCount: _visible.length,
                      itemBuilder: (_, i) => _TechniqueCard(_visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AppTheme.body(14),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: 'Search techniques',
        hintStyle: AppTheme.body(14, color: AppColors.textMuted),
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
  const _TechniqueCard(this.t);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
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
                      style: AppTheme.body(10,
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                          spacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(t.title,
                      style: AppTheme.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${t.videoCount} videos',
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
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
