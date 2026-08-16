import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'user_notes.dart';

/// Extra 支持者公开鸣谢 (原版 packed advance.json 未移植)
const kSponsorNamed = <(String, String)>[
  ('senken', '提供 iOS 开发账号'),
  ('magma', '提供服务器和 OSS'),
];

/// 赞助者 (原版 Header 图表/列表切换 + 说明)
class SponsorScreen extends StatefulWidget {
  const SponsorScreen({super.key});

  @override
  State<SponsorScreen> createState() => _SponsorScreenState();
}

class _SponsorScreenState extends State<SponsorScreen> {
  bool _list = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: BgmAppBar(
        title: '支持者',
        actions: [
          BgmHeaderAction(
            tooltip: _list ? '图表' : '列表',
            icon: Icon(_list ? Icons.insert_chart_outlined : Icons.sort),
            onPressed: () => setState(() => _list = !_list),
          ),
          BgmHeaderAction(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(sponsorNotePath()),
          ),
        ],
      ),
      body: _list
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  '截止目前共有具名支持者 ${kSponsorNamed.length} 人，另有 50 多个支持者没有留名。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in kSponsorNamed)
                  BgmSettingRow(
                    title: '@${item.$1}',
                    subtitle: item.$2,
                    onTap: () => context.push('/user/${item.$1}'),
                    onLongPress: () => context.push('/user/${item.$1}'),
                  ),
                const SizedBox(height: 16),
                Text(
                  '图表根据支持额按比例划分。完整名单依赖原版打包数据，未随本客户端分发。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_chart_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text('图表根据支持额按比例划分。', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      '点击方格隐藏 1 格，若你为支持者长按可进入空间。完整矩形图依赖原版打包数据，未随本客户端分发。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BgmTextAction(
                      '打开原项目支持页',
                      onPressed: () =>
                          openExternalUrl('https://github.com/czy0729/Bangumi'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
