import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/storage/cache.dart';

/// Webhook 设置 (移植自原项目 screens/web-view/webhook)
///
/// 收藏变化等事件可通过 Webhook 推送到自定义地址 (持久化于 hive settings box)。
/// 路由: /webhook
class WebhookScreen extends ConsumerStatefulWidget {
  const WebhookScreen({super.key});

  @override
  ConsumerState<WebhookScreen> createState() => _WebhookScreenState();
}

class _WebhookScreenState extends ConsumerState<WebhookScreen> {
  static const _kKey = 'webhook_urls';
  final _controller = TextEditingController();

  Box<dynamic> get _box => ref.read(cacheProvider).box('settings');

  List<String> _urls() => (_box.get(_kKey) as List?)?.cast<String>() ?? const [];

  Future<void> _add() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入以 http(s):// 开头的地址')),
      );
      return;
    }
    final urls = _urls();
    if (urls.contains(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该地址已存在')),
      );
      return;
    }
    await _box.put(_kKey, [...urls, url]);
    _controller.clear();
    setState(() {});
  }

  Future<void> _remove(String url) async {
    await _box.put(_kKey, _urls().where((e) => e != url).toList());
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls();
    return Scaffold(
      appBar: AppBar(title: const Text('Webhook 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '当收藏发生变化时, 应用会向以下地址推送 Webhook 通知, 可用于配合自动化工作流。',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/webhook',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _add, child: const Text('添加')),
            ],
          ),
          const SizedBox(height: 16),
          if (urls.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('暂无 Webhook 地址')),
            )
          else
            ...urls.map(
              (url) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 20),
                  title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _remove(url),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
