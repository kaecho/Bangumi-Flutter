import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'versions_screen.dart' show kAppVersion;

/// 关于页面 (移植自原项目 screens/web-view/information)
/// 路由: /about
class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开链接')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.tv, size: 40, color: scheme.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bangumi 番组计划',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Flutter 客户端 v$kAppVersion',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('项目简介'),
                  subtitle: const Text(
                    'Bangumi 第三方客户端, 与原项目 (czy0729/Bangumi) 功能 1:1 对应。'
                    '数据来自 bgm.tv 公开 API。',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('GitHub 仓库'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, 'https://github.com/kaecho/Bangumi-Flutter'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Bangumi 番组计划'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, 'https://bgm.tv'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: const Text('开源许可'),
                  subtitle: const Text('MIT License'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
