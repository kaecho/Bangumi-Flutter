import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/url_match.dart';
import '../../design_system/design_system.dart';

/// 原项目 discovery/index LinkModal LINKS
const kClipboardPresets = <({String key, String value, String text})>[
  (key: '条目', value: '$kHost/subject/', text: '$kHost/subject/{ID}'),
  (key: '帖子', value: '$kHost/group/topic/', text: '$kHost/group/topic/{ID}'),
  (key: '小组', value: '$kHost/group/', text: '$kHost/group/{ID}'),
  (key: '虚拟人物', value: '$kHost/character/', text: '$kHost/character/{ID}'),
  (key: '现实人物', value: '$kHost/person/', text: '$kHost/person/{ID}'),
  (key: '用户空间', value: '$kHost/user/', text: '$kHost/user/{ID}'),
  (key: '标签', value: '$kHost/tag/', text: '$kHost/tag/{ID}'),
  (key: '目录', value: '$kHost/index/', text: '$kHost/index/{ID}'),
  (key: '日志', value: '$kHost/blog/', text: '$kHost/blog/{ID}'),
  (
    key: '用户目录',
    value: '$kHost/user/替换ID/index',
    text: '$kHost/user/{ID}/index',
  ),
  (key: '用户日志', value: '$kHost/user/替换ID/blog', text: '$kHost/user/{ID}/blog'),
  (key: '用户人物', value: '$kHost/user/替换ID/mono', text: '$kHost/user/{ID}/mono'),
  (
    key: '用户好友',
    value: '$kHost/user/替换ID/friends',
    text: '$kHost/user/{ID}/friends',
  ),
];

class ClipboardSheet extends StatefulWidget {
  const ClipboardSheet({super.key});

  @override
  State<ClipboardSheet> createState() => _ClipboardSheetState();
}

class _ClipboardSheetState extends State<ClipboardSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _submit() {
    var link = _controller.text.trim();
    if (link.isEmpty) {
      _toast('请输入链接');
      return;
    }
    if (link.contains('替换')) {
      _toast('请把链接中的替换ID覆盖为指定的用户ID');
      return;
    }
    if (!link.contains('http://') && !link.contains('https://')) {
      link = 'https://$link';
    }
    final url = matchBgmUrl(link);
    final route = url == null ? null : bgmUrlToRoute(url);
    if (route == null) {
      _toast('链接不符合格式');
      return;
    }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  Future<void> _pickPreset() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('预设')),
            for (final item in kClipboardPresets)
              ListTile(
                title: Text(item.key),
                subtitle: Text(item.text, style: context.ds.caption),
                onTap: () => Navigator.pop(ctx, item.value),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _controller.text = selected);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '剪贴板',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppGap.x2),
            Text('可能由于权限问题，未能在剪贴板中匹配到链接，请手动粘贴或输入', style: context.ds.caption),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '输入或粘贴 bgm.tv 的链接',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: _pickPreset, child: const Text('预设')),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('提交')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
