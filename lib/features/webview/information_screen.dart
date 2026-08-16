import 'package:flutter/material.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import 'versions_screen.dart' show kAppVersion;

/// 关于页面 (移植自原项目 screens/web-view/information)
/// 路由: /about
class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    await openExternalUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: BgmAppBar(title: '关于'),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BgmCard(
            child: Column(
              children: [
                BgmSettingRow(
                  title: '项目简介',
                  subtitle:
                      'Bangumi 第三方客户端, 与原项目 (czy0729/Bangumi) 功能 1:1 对应。数据来自 bgm.tv 公开 API。',
                ),
                const BgmHairline(),
                BgmSettingRow(
                  title: 'GitHub 仓库',
                  arrow: true,
                  onTap: () => _open(
                    context,
                    'https://github.com/kaecho/Bangumi-Flutter',
                  ),
                ),
                const BgmHairline(),
                BgmSettingRow(
                  title: 'Bangumi 番组计划',
                  arrow: true,
                  onTap: () => _open(context, 'https://bgm.tv'),
                ),
                const BgmHairline(),
                BgmSettingRow(title: '开源许可', subtitle: 'MIT License'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
