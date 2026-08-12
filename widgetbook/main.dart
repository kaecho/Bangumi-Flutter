import 'package:bangumi/app/theme.dart';
import 'package:bangumi/design_system/design_system.dart';
import 'package:bangumi/shared/widgets/app_bar.dart';
import 'package:bangumi/shared/widgets/cover.dart';
import 'package:bangumi/shared/widgets/loading.dart';
import 'package:bangumi/shared/widgets/score.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// 设计系统目录 — `flutter run -t widgetbook/main.dart`
void main() => runApp(const WidgetbookApp());

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: AppTheme.light(AppPalette.defaultAccent)),
            WidgetbookTheme(name: 'Dark', data: AppTheme.dark(AppPalette.defaultAccent)),
          ],
        ),
      ],
      directories: [
        WidgetbookCategory(
          name: 'Foundation',
          children: [
            WidgetbookUseCase(name: 'Colors', builder: (_) => const _ColorGallery()),
            WidgetbookUseCase(name: 'Typography', builder: (_) => const _TypeGallery()),
            WidgetbookUseCase(name: 'Spacing & Radius', builder: (_) => const _SpacingGallery()),
          ],
        ),
        WidgetbookCategory(
          name: 'Components',
          children: [
            WidgetbookComponent(
              name: 'Tag',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Center(
                    child: Tag(
                      text: context.knobs.string(label: 'text', initialValue: 'TV 动画'),
                      active: context.knobs.boolean(label: 'active'),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Filter Row',
                  builder: (_) => const _TagRow(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Score',
              useCases: [
                WidgetbookUseCase(
                  name: 'Score',
                  builder: (context) => Center(
                    child: Score(
                      score: context.knobs.double.slider(
                        label: 'score',
                        initialValue: 7.5,
                        min: 0,
                        max: 10,
                      ),
                      total: 1234,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Stars',
                  builder: (context) => Center(
                    child: Stars(
                      score: context.knobs.double.slider(
                        label: 'score',
                        initialValue: 7.5,
                        min: 0,
                        max: 10,
                      ),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Cover & Avatar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Cover placeholder',
                  builder: (_) => const Center(
                    child: Cover(url: '', width: 100, height: 130, radius: AppRadius.m),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Avatar fallback',
                  builder: (context) => Center(
                    child: Avatar(
                      url: '',
                      size: 48,
                      name: context.knobs.string(label: 'name', initialValue: '坂本'),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Feedback',
              useCases: [
                WidgetbookUseCase(
                  name: 'Loading',
                  builder: (_) => const Loading(height: 200, text: '加载中'),
                ),
                WidgetbookUseCase(name: 'Empty', builder: (_) => const Empty()),
                WidgetbookUseCase(
                  name: 'Skeleton',
                  builder: (_) => const Center(
                    child: Skeleton(width: 120, height: 16),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SectionHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => const Column(
                    children: [
                      SectionHeader(title: '简介'),
                      SectionHeader(
                        title: '章节',
                        trailing: Text('全部'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmAppBar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => const Scaffold(
                    appBar: BgmAppBar(title: '条目详情', showBackButton: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorGallery extends StatelessWidget {
  const _ColorGallery();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final entries = [
      ('accent', ds.accent),
      ('accentSoft', ds.accentSoft),
      ('star', ds.star),
      ('rise', ds.rise),
      ('fall', ds.fall),
      ('success', ds.success),
      ('error', ds.error),
      ('textPrimary', ds.textPrimary),
      ('textSecondary', ds.textSecondary),
      ('textHint', ds.textHint),
      ('surfaceBase', ds.surfaceBase),
      ('surfaceCard', ds.surfaceCard),
      ('border', ds.border),
    ];
    return ListView(
      padding: AppGap.card,
      children: [
        for (final (name, color) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.x2),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.sAll,
                    border: Border.all(color: ds.border),
                  ),
                ),
                const SizedBox(width: AppGap.x6),
                Text(name, style: ds.body),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeGallery extends StatelessWidget {
  const _TypeGallery();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final entries = [
      ('display 20/700', ds.display),
      ('title 17/600', ds.title),
      ('section 15/600', ds.section),
      ('bodyStrong 14/500', ds.bodyStrong),
      ('body 14/400', ds.body),
      ('label 13/400', ds.label),
      ('caption 12/400', ds.caption),
      ('meta 11/400', ds.meta),
      ('tiny 10/400', ds.tiny),
    ];
    return ListView(
      padding: AppGap.card,
      children: [
        for (final (name, style) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(width: 140, child: Text(name, style: ds.meta)),
                Text(' Bangumi 番组计划', style: style),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpacingGallery extends StatelessWidget {
  const _SpacingGallery();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    const gaps = [
      ('x1', AppGap.x1),
      ('x2', AppGap.x2),
      ('x3', AppGap.x3),
      ('x4', AppGap.x4),
      ('x5', AppGap.x5),
      ('x6', AppGap.x6),
      ('x7', AppGap.x7),
      ('x8', AppGap.x8),
      ('x10', AppGap.x10),
    ];
    const radii = [
      ('s', AppRadius.s),
      ('m', AppRadius.m),
      ('l', AppRadius.l),
      ('xl', AppRadius.xl),
    ];
    return ListView(
      padding: AppGap.card,
      children: [
        Text('Spacing', style: ds.section),
        const SizedBox(height: AppGap.x4),
        for (final (name, v) in gaps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.x1),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('$name = $v', style: ds.meta)),
                Container(width: v, height: 14, color: ds.accent),
              ],
            ),
          ),
        const SizedBox(height: AppGap.x8),
        Text('Radius', style: ds.section),
        const SizedBox(height: AppGap.x4),
        for (final (name, v) in radii)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.x2),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('$name = $v', style: ds.meta)),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ds.accentSoft,
                    border: Border.all(color: ds.accent),
                    borderRadius: BorderRadius.circular(v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TagRow extends StatefulWidget {
  const _TagRow();

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    const tags = ['全部', '动画', '书籍', '游戏', '三次元'];
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, t) in tags.indexed)
            Padding(
              padding: const EdgeInsets.only(right: AppGap.x4),
              child: Tag(
                text: t,
                active: i == _active,
                onTap: () => setState(() => _active = i),
              ),
            ),
        ],
      ),
    );
  }
}
