import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/settings_store.dart';
import '../../design_system/colors.dart';

/// 首页 Tab 开关项 (与原项目 homeRenderTabs 一致)
const kHomeRenderTabOptions = [
  ('Discovery', '发现'),
  ('Timeline', '时间线'),
  ('Home', '首页'),
  ('Rakuen', '超展开'),
  ('User', '我的'),
];

/// 初始页面选项
const kInitialPageOptions = [
  ('Home', '首页'),
  ('Discovery', '发现'),
  ('Timeline', '时间线'),
  ('Rakuen', '超展开'),
  ('User', '我的'),
];

/// 图片质量选项
const kImageQualityOptions = [
  ('grid', '网格'),
  ('small', '小'),
  ('medium', '中'),
  ('common', '较大'),
  ('large', '大'),
];

/// 设置
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionHeader('外观'),
          _ThemeModeTile(store: store),
          _ColorTile(store: store),
          _SwitchTile(
            title: '动态取色',
            subtitle: '跟随系统动态取色 (Android 12+)',
            value: store.dynamicColor,
            onChanged: (v) => store.setDynamicColor(v),
          ),
          _SwitchTile(
            title: '封面过渡',
            subtitle: '封面加载淡入动画',
            value: store.coverFadeIn,
            onChanged: (v) => store.setCoverFadeIn(v),
          ),
          _SectionHeader('首页'),
          _HomeTabsTile(store: store),
          _InitialPageTile(store: store),
          _SwitchTile(
            title: '底部懒加载',
            subtitle: '切换 Tab 时才加载页面',
            value: store.bottomTabLazy,
            onChanged: (v) => store.setBottomTabLazy(v),
          ),
          _SectionHeader('图片'),
          _ImageQualityTile(store: store),
          _SectionHeader('功能'),
          _SwitchTile(
            title: '小圣杯',
            subtitle: '在底部显示小圣杯入口',
            value: store.tinygrailEnabled,
            onChanged: (v) => store.setTinygrailEnabled(v),
          ),
          _SectionHeader('其他'),
          _LinkTile('站点 Cookie 登录', Icons.cookie_outlined, '/settings/cookies'),
          _LinkTile('个人设置', Icons.person_outline, '/settings/user'),
          _LinkTile('源头设置', Icons.link, '/settings/origin'),
          _LinkTile('服务器状态', Icons.monitor_heart_outlined, '/settings/status'),
          _LinkTile('操作记录', Icons.history, '/settings/actions'),
          _LinkTile('我的卡片', Icons.badge_outlined, '/settings/qiafan'),
          _LinkTile('本地管理', Icons.folder_outlined, '/settings/smb'),
          _LinkTile('本地备份', Icons.inbox_outlined, '/settings/backup'),
          _LinkTile('赞助', Icons.favorite_outline, '/settings/sponsor'),
          _LinkTile('开发', Icons.code, '/settings/dev'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final SettingsStore store;

  const _ThemeModeTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('主题模式'),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
          ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
          ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
        ],
        selected: {store.themeMode},
        onSelectionChanged: (s) => store.setThemeMode(s.first),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final SettingsStore store;

  const _ColorTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.primaryColor;
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题色'),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final color in AppPalette.accentColors)
            InkWell(
              onTap: () => store.setPrimaryColor(color),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color == current
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                      : null,
                ),
                child: color == current
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeTabsTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeTabsTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final enabled = store.homeRenderTabs;
    return ListTile(
      leading: const Icon(Icons.tab_outlined),
      title: const Text('首页 Tabs'),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (key, label) in kHomeRenderTabOptions)
            FilterChip(
              label: Text(label),
              selected: enabled.contains(key),
              onSelected: (on) {
                final next = [...enabled];
                if (on) {
                  if (!next.contains(key)) next.add(key);
                } else {
                  next.remove(key);
                }
                store.setHomeRenderTabs(next);
              },
            ),
        ],
      ),
    );
  }
}

class _InitialPageTile extends StatelessWidget {
  final SettingsStore store;

  const _InitialPageTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.initialPage;
    return ListTile(
      leading: const Icon(Icons.home_outlined),
      title: const Text('初始页面'),
      trailing: DropdownButton<String>(
        value: kInitialPageOptions.any((e) => e.$1 == current) ? current : 'Home',
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kInitialPageOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setInitialPage(v);
        },
      ),
    );
  }
}

class _ImageQualityTile extends StatelessWidget {
  final SettingsStore store;

  const _ImageQualityTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.imageQuality;
    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: const Text('图片质量'),
      trailing: DropdownButton<String>(
        value: kImageQualityOptions.any((e) => e.$1 == current) ? current : 'medium',
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kImageQualityOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setImageQuality(v);
        },
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String path;

  const _LinkTile(this.title, this.icon, this.path);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push(path),
    );
  }
}
