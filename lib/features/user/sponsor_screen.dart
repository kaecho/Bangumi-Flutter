import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'user_notes.dart';

/// 赞助 (静态感谢页)
class SponsorScreen extends StatelessWidget {
  const SponsorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('支持者'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(sponsorNotePath()),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.favorite, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          const Text(
            '感谢你的支持!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            '本应用是开源项目, 开发维护需要大量时间和精力。\n如果你觉得好用, 欢迎赞助一杯咖啡, 支持持续开发。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    '支付宝 / 微信',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '收款二维码图片暂未打包, 敬请期待。\n你也可以通过 GitHub Sponsor 支持原项目: github.com/czy0729/Bangumi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '所有赞助将用于服务器与域名开销, 感谢每一位支持者。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
