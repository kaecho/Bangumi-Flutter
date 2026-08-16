import 'package:bangumi/app/theme.dart';
import 'package:bangumi/design_system/design_system.dart';
import 'package:bangumi/shared/widgets/app_bar.dart';
import 'package:bangumi/shared/widgets/cover.dart';
import 'package:bangumi/shared/widgets/loading.dart';
import 'package:bangumi/shared/widgets/score.dart';
import 'package:bangumi/shared/widgets/tab_bar.dart';
import 'package:bangumi/shared/widgets/tab_title.dart';
import 'package:bangumi/shared/widgets/bgm_button.dart';
import 'package:bangumi/shared/widgets/menu_mark.dart';

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
            WidgetbookTheme(
              name: 'Light',
              data: AppTheme.light(AppPalette.defaultAccent),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: AppTheme.dark(AppPalette.defaultAccent),
            ),
          ],
        ),
      ],
      directories: [
        WidgetbookCategory(
          name: 'Foundation',
          children: [
            WidgetbookUseCase(
              name: 'Colors',
              builder: (_) => const _ColorGallery(),
            ),
            WidgetbookUseCase(
              name: 'Typography',
              builder: (_) => const _TypeGallery(),
            ),
            WidgetbookUseCase(
              name: 'Spacing & Radius',
              builder: (_) => const _SpacingGallery(),
            ),
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
                      text: context.knobs.string(
                        label: 'text',
                        initialValue: 'TV 动画',
                      ),
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
                WidgetbookUseCase(
                  name: 'ScoreTag',
                  builder: (context) => Center(
                    child: ScoreTag(
                      value: context.knobs.double.slider(
                        label: 'score',
                        initialValue: 8,
                        min: 0,
                        max: 10,
                      ),
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
                    child: Cover(
                      url: '',
                      width: 100,
                      height: 130,
                      radius: AppRadius.m,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Avatar fallback',
                  builder: (context) => Center(
                    child: Avatar(
                      url: '',
                      size: 48,
                      name: context.knobs.string(
                        label: 'name',
                        initialValue: '坂本',
                      ),
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
                  builder: (_) =>
                      const Center(child: Skeleton(width: 120, height: 16)),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SectionHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => Column(
                    children: [
                      const SectionHeader(title: '简介'),
                      SectionHeader(
                        title: '章节',
                        trailing: SectionMore(onTap: () {}),
                      ),
                      LoadMoreLink(label: '加载更多', onTap: () {}),
                    ],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmSelect',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Center(
                    child: BgmSelect<String>(
                      value: context.knobs.object.dropdown(
                        label: 'value',
                        options: const ['web', 'onair', 'default'],
                        initialOption: 'onair',
                      ),
                      items: const [
                        ('web', '网页'),
                        ('onair', '放送'),
                        ('default', 'APP'),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmField',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: BgmField(
                      hintText: context.knobs.string(
                        label: 'hint',
                        initialValue: '说点什么...',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmSettingRow',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => Column(
                    children: [
                      BgmSettingRow(
                        title: '看板娘吐槽',
                        subtitle: '空列表底部显示 Bangumi 娘',
                        trailing: BgmSwitch(value: true, onChanged: (_) {}),
                      ),
                      BgmSettingRow(title: '源头设置', arrow: true, onTap: () {}),
                    ],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmTextRow',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => const Column(
                    children: [
                      BgmTextRow(
                        title: '关于新番讨论',
                        replies: 12,
                        subtitle: '动画 / 用户A',
                      ),
                      BgmTextRow(title: '本地收录', subtitle: 'SMB 目录'),
                    ],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmHeaderAction',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => const Row(
                    children: [
                      BgmHeaderAction(icon: Icon(Icons.notifications_outlined)),
                      BgmHeaderAction(icon: Icon(Icons.search)),
                    ],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmHeaderMore',
              useCases: [
                WidgetbookUseCase(
                  name: 'Browser',
                  builder: (_) => BgmHeaderMore.browser(() {}),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmDiscoveryExtra',
              useCases: [
                WidgetbookUseCase(
                  name: 'List',
                  builder: (_) => BgmDiscoveryExtra(
                    isList: true,
                    onToggleLayout: () {},
                    onScrollToTop: () {},
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
                WidgetbookUseCase(
                  name: 'Overlay',
                  builder: (_) => const Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: BgmAppBar(
                      title: '条目',
                      showBackButton: true,
                      transparent: true,
                      foregroundColor: Colors.white,
                    ),
                    body: ColoredBox(color: Colors.black54),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'LogoHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Centered logo',
                  builder: (_) => const Scaffold(appBar: LogoHeader()),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmTabBar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Selected label only',
                  builder: (_) => Scaffold(
                    bottomNavigationBar: BgmTabBar(
                      index: 2,
                      onSelect: (_) {},
                      tabs: const [
                        BgmTabItem(
                          key: 'Discovery',
                          label: '发现',
                          icon: BgmIcons.home,
                          iconSize: 19,
                          path: '/discovery',
                          child: SizedBox.shrink(),
                          alwaysShow: true,
                        ),
                        BgmTabItem(
                          key: 'Timeline',
                          label: '时间胶囊',
                          icon: Icons.access_time,
                          iconSize: 21,
                          path: '/timeline',
                          child: SizedBox.shrink(),
                          alwaysShow: true,
                        ),
                        BgmTabItem(
                          key: 'Home',
                          label: '收藏',
                          icon: Icons.star_outline,
                          path: '/progress',
                          child: SizedBox.shrink(),
                          alwaysShow: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            WidgetbookComponent(
              name: 'BgmButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Types',
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        BgmButton('登录'),
                        SizedBox(height: 12),
                        BgmButton('次要', type: BgmButtonType.plain),
                        SizedBox(height: 12),
                        BgmButton('浅底', type: BgmButtonType.ghost),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmTabStrip',
              useCases: [
                WidgetbookUseCase(
                  name: 'Underline',
                  builder: (_) => BgmTabStrip(
                    index: 1,
                    onSelect: (_) {},
                    tabs: const [Text('全部'), Text('动画'), Text('书籍')],
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmFilterChip',
              useCases: [
                WidgetbookUseCase(
                  name: 'Selected',
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        BgmFilterChip(
                          label: '全部',
                          selected: true,
                          onTap: () {},
                        ),
                        BgmFilterChip(
                          label: '动画',
                          selected: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmRetry',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => BgmRetry(onRetry: () {}),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmSwitch',
              useCases: [
                WidgetbookUseCase(
                  name: 'On Off',
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      children: [
                        BgmSwitch(value: true),
                        SizedBox(width: 16),
                        BgmSwitch(value: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmSegmented',
              useCases: [
                WidgetbookUseCase(
                  name: 'Theme',
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: BgmSegmented<String>(
                      values: const [
                        ('light', '浅色'),
                        ('dark', '深色'),
                        ('system', '跟随'),
                      ],
                      selected: 'dark',
                      onSelect: (_) {},
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmDialog',
              useCases: [
                WidgetbookUseCase(
                  name: 'Confirm',
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: BgmDialog(
                      title: '退出登录',
                      content: Text('将清除本地 token 与站点 Cookie'),
                      actions: [
                        BgmButton(
                          '取消',
                          type: BgmButtonType.plain,
                          expand: false,
                        ),
                        BgmButton('退出', expand: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmHairline',
              useCases: [
                WidgetbookUseCase(
                  name: 'Indented',
                  builder: (_) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: BgmHairline(indent: 56),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BgmMenuMark / Notify',
              useCases: [
                WidgetbookUseCase(
                  name: 'Wrap Badge Notify',
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      children: [
                        BgmMenuMark(icon: Icons.folder, badge: Icons.favorite),
                        SizedBox(width: 16),
                        BgmMenuMark(
                          icon: Icons.attach_money,
                          text: 'D',
                          wrap: false,
                        ),
                        SizedBox(width: 16),
                        BgmNotifyMark(unread: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            WidgetbookComponent(
              name: 'BgmCard / Expand / Toast / Slider',
              useCases: [
                WidgetbookUseCase(
                  name: 'Card Expand Slider',
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        BgmCard(
                          padding: const EdgeInsets.all(12),
                          child: BgmExpand(
                            title: '使用技巧',
                            subtitle: '点开展开',
                            children: [Text('验证码会自动识别, 也可点图刷新')],
                          ),
                        ),
                        const SizedBox(height: 16),
                        BgmSlider(
                          value: 7,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        const BgmSpinner(),
                        const SizedBox(height: 12),
                        BgmTextAction('加载更多', onPressed: () {}),
                      ],
                    ),
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
