import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'user_models.dart';

/// 原版 qiafan HeaderV2 title
const kQiafanTitle = '关于客户端';

/// 关于客户端 (原版 qiafan Section1-4 文案)
class QiafanScreen extends ConsumerWidget {
  const QiafanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const BgmAppBar(title: kQiafanTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            '自 19 年 2 月以来项目已持续开发。第一次做 APP，最初仅为用于练手，后来发现很有趣便一直开发至今。好看 >> 好用 > 速度 >>> 稳定性 一直都是本客户端的开发方向。',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          const Text(
            '作为一个第三方客户端，相较于网页 bgm.tv 在出发点上可能会存在分歧，客户端的主要目的还是通过聚合各种元素，让用户比网页版更容易发现喜欢的番剧。无任欢迎提各种意见和需求。',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          const Text(
            '您的支持就是作者继续开发下去的动力，觉得好用的不忘到 Github 上给星星。',
            style: TextStyle(height: 1.7),
          ),
          const BgmHairline(),
          const SizedBox(height: 12),
          const Text(
            '客户端内并没有直接播放视频的功能，请你先知悉客户端是用来干什么的！',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          const Text(
            '如果你觉得这个项目对你有帮助，可以通过支持项目发展并留言 / 告知用户 id，作者看见会第一时间为您开放额外权益。',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 16),
          const Text(
            '支持者的额外权益',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text('客户端：完整使用多达百个功能 / 页面'),
          const SizedBox(height: 8),
          const Text('条目封面：备用图片源（需支持过项目发展）'),
          const SizedBox(height: 8),
          const Text('需求反馈：优先跟进'),
          const SizedBox(height: 8),
          const Text('进度：支持最大显示 300 个在看条目'),
          const SizedBox(height: 8),
          const Text('哔哩同步 / 豆瓣同步：完整同步功能'),
          const SizedBox(height: 16),
          const Text(
            '支持项目发展',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            me == null
                ? '如果你想支持这个项目继续发展，可以在支持时备注你的站内 bgm 的 id。你的支持是作者持续用爱发电的动力！'
                : '如果你想支持这个项目继续发展，可以在支持时备注你的站内 bgm 的 id，留下这个 ${userPathId(me)}。你的支持是作者持续用爱发电的动力！',
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 16),
          BgmButton(
            '支持者名单',
            type: BgmButtonType.plain,
            onPressed: () => context.push('/settings/sponsor'),
          ),
          const SizedBox(height: 8),
          BgmTextAction(
            '打开支付宝收款图',
            onPressed: () => openExternalUrl(
              'https://lsky.ry.mk/i/2026/05/15/13bfe904b76d7.webp',
            ),
          ),
          BgmTextAction(
            '打开微信收款图',
            onPressed: () => openExternalUrl(
              'https://lsky.ry.mk/i/2026/05/15/3c098ee47ec1c.webp',
            ),
          ),
        ],
      ),
    );
  }
}
