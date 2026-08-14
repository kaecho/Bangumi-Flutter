import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'rakuen_settings.dart';
import '../../design_system/design_system.dart';

/// 超展开设置 (屏蔽规则 / 楼层样式 / 引用折叠)
/// 路由: /rakuen/setting
class RakuenSettingScreen extends ConsumerStatefulWidget {
  const RakuenSettingScreen({super.key});

  @override
  ConsumerState<RakuenSettingScreen> createState() =>
      _RakuenSettingScreenState();
}

class _RakuenSettingScreenState extends ConsumerState<RakuenSettingScreen> {
  final _userController = TextEditingController();
  final _groupController = TextEditingController();
  final _keywordController = TextEditingController();
  final _trackController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _groupController.dispose();
    _keywordController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  Future<void> _add(String kind) async {
    final controller = switch (kind) {
      'user' => _userController,
      'group' => _groupController,
      'track' => _trackController,
      _ => _keywordController,
    };
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final settings = ref.read(rakuenSettingsProvider.notifier);
    if (kind == 'user') {
      await settings.addBlockUser(text);
      _userController.clear();
    } else if (kind == 'group') {
      await settings.addBlockGroup(text);
      _groupController.clear();
    } else if (kind == 'track') {
      await settings.trackUser(text);
      _trackController.clear();
    } else {
      await settings.addBlockKeyword(text);
      _keywordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(rakuenSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('超展开设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionTitle('帖子'),
          _SwitchItem(
            title: '展开引用',
            subtitle: '展开子回复中上一级的回复内容',
            value: settings.quote,
            onChanged: (v) =>
                ref.read(rakuenSettingsProvider.notifier).setBool('quote', v),
          ),
          if (settings.quote)
            _SwitchItem(
              title: '显示引用头像',
              value: settings.quoteAvatar,
              onChanged: (v) => ref
                  .read(rakuenSettingsProvider.notifier)
                  .setBool('quoteAvatar', v),
            ),
          _SwitchItem(
            title: '楼层加宽展示',
            value: settings.wide,
            onChanged: (v) =>
                ref.read(rakuenSettingsProvider.notifier).setBool('wide', v),
          ),
          _SegmentedItem<String>(
            title: '子楼层折叠',
            subtitle: '子回复超过此值后折叠; 0 代表一直折叠',
            options: kSubExpandOptions,
            value: settings.subExpand,
            label: (v) => v,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setString('subExpand', v),
          ),
          _SegmentedItem<String>(
            title: '楼层样式',
            options: [for (final o in kFloorStyleOptions) o.$2],
            value: settings.floorStyle,
            label: (v) => kFloorStyleOptions
                .firstWhere((o) => o.$2 == v, orElse: () => ('', v))
                .$1,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setString('floorStyle', v),
          ),
          _SegmentedItem<String>(
            title: '图片自动加载',
            subtitle: '楼层中图片自动加载 (建议谨慎开启自动加载)',
            options: [for (final o in kAutoLoadImageOptions) o.$2],
            value: settings.autoLoadImage,
            label: (v) => kAutoLoadImageOptions
                .firstWhere((o) => o.$2 == v, orElse: () => ('', v))
                .$1,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setString('autoLoadImage', v),
          ),
          _SwitchItem(
            title: '过滤用户删除的楼层',
            value: settings.filterDelete,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('filterDelete', v),
          ),
          _SwitchItem(
            title: '标记坟贴',
            subtitle: '超过 90 天未回复的主题显示提醒',
            value: settings.markOldTopic,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('markOldTopic', v),
          ),
          _SwitchItem(
            title: '长楼层收起按钮',
            subtitle: '超长回复显示收起按钮',
            value: settings.showFoldButton,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('showFoldButton', v),
          ),
          _SwitchItem(
            title: '长楼层漂浮收起',
            subtitle: '子楼层展开后右下角显示收起按钮',
            value: settings.showFixedToggleFloorBtn,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('showFixedToggleFloorBtn', v),
          ),

          _SwitchItem(
            title: '贴贴模块',
            subtitle: '帖子回复显示贴贴数, 不建议关闭',
            value: settings.likes,
            onChanged: (v) =>
                ref.read(rakuenSettingsProvider.notifier).setBool('likes', v),
          ),
          _SegmentedItem<String>(
            title: '楼层直达条',
            options: [for (final o in kScrollDirectionOptions) o.$2],
            value: settings.scrollDirection,
            label: (v) => kScrollDirectionOptions
                .firstWhere((o) => o.$2 == v, orElse: () => ('', v))
                .$1,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setString('scrollDirection', v),
          ),
          _SwitchItem(
            title: '楼层链接显示成信息块',
            subtitle: '条目链接改成卡片而不是纯文字',
            value: settings.matchLink,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('matchLink', v),
          ),
          _SegmentedItem<int>(
            title: '大表情尺寸',
            options: const [28, 36, 48],
            value: settings.bigEmojiSize,
            label: (v) => switch (v) {
              28 => '小',
              48 => '大',
              _ => '中',
            },
            onChanged: (v) =>
                ref.read(rakuenSettingsProvider.notifier).setBigEmojiSize(v),
          ),
          _SwitchItem(
            title: '楼层跳转滚动动画',
            value: settings.sliderAnimated,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('sliderAnimated', v),
          ),
          _SwitchItem(
            title: '交换跳转按钮',
            subtitle: '上一层 / 下一层 对调',
            value: settings.switchSlider,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('switchSlider', v),
          ),

          _SectionTitle('屏蔽'),
          _SwitchItem(
            title: '屏蔽默认头像用户的帖子',
            value: settings.blockDefaultUser,
            onChanged: (v) => ref
                .read(rakuenSettingsProvider.notifier)
                .setBool('blockDefaultUser', v),
          ),
          _BlockListEditor(
            title: '屏蔽用户',
            subtitle: '不再看到该用户的所有话题与评论',
            items: settings.blockUsers,
            controller: _userController,
            addHint: '输入用户 ID 或用户名',
            onAdd: () => _add('user'),
            onDelete: (v) =>
                ref.read(rakuenSettingsProvider.notifier).removeBlockUser(v),
          ),
          _BlockListEditor(
            title: '屏蔽小组 / 条目 / 人物',
            subtitle: '对帖子所属小组名生效',
            items: settings.blockGroups,
            controller: _groupController,
            addHint: '输入小组名',
            onAdd: () => _add('group'),
            onDelete: (v) =>
                ref.read(rakuenSettingsProvider.notifier).removeBlockGroup(v),
          ),
          _BlockListEditor(
            title: '屏蔽关键词',
            subtitle: '匹配帖子标题与楼层内容',
            items: settings.blockKeywords,
            controller: _keywordController,
            addHint: '输入关键词',
            onAdd: () => _add('keyword'),
            onDelete: (v) =>
                ref.read(rakuenSettingsProvider.notifier).removeBlockKeyword(v),
          ),
          _BlockListEditor(
            title: '追踪回复',
            subtitle: '楼层菜单也可追踪, 头像会加标记',
            items: settings.commentTrack,
            controller: _trackController,
            addHint: '输入用户 ID',
            onAdd: () => _add('track'),
            onDelete: (v) =>
                ref.read(rakuenSettingsProvider.notifier).untrackUser(v),
          ),

          ListTile(
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/rakuen/ugc-agree'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}

class _SegmentedItem<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<T> options;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _SegmentedItem({
    required this.title,
    this.subtitle,
    required this.options,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: context.ds.caption),
            ),
          const SizedBox(height: 8),
          SegmentedButton<T>(
            segments: [
              for (final option in options)
                ButtonSegment(value: option, label: Text(label(option))),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}

class _BlockListEditor extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final TextEditingController controller;
  final String addHint;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  const _BlockListEditor({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.controller,
    required this.addHint,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: context.ds.caption),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: addHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add),
                color: theme.colorScheme.primary,
                onPressed: onAdd,
              ),
            ],
          ),
          if (items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final item in items)
                  InputChip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => onDelete(item),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
