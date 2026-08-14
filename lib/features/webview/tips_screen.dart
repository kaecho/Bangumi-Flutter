import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';

/// 使用技巧条目
class TipItem {
  final String title;
  final String content;

  const TipItem({required this.title, required this.content});
}

/// 使用技巧列表 (移植自原项目 screens/web-view/tips 文档主题)
const List<TipItem> kTips = [
  TipItem(
    title: '图片无法加载',
    content:
        '图片加载失败时, 可以在「我的 → 设置」中切换图片代理或刷新网络。'
        '大陆网络环境下推荐开启镜像/反代, 详见「代理帮助」。',
  ),
  TipItem(
    title: '封面加速',
    content:
        '封面图默认使用 bgm.tv 图床, 加载缓慢时可尝试切换封面 CDN 镜像, '
        '或使用代理模式访问。',
  ),
  TipItem(
    title: '源头和跳转',
    content:
        '条目页的「源头」会展示该条目在豆瓣、维基等站点的链接, '
        '点击外部链接默认在应用内置浏览器中打开。',
  ),
  TipItem(
    title: '番剧推荐',
    content:
        '发现页的「推荐」会根据你的收藏和评分习惯推荐条目。'
        '多收藏、多评分可以获得更准确的推荐结果。',
  ),
  TipItem(
    title: '屏蔽用户',
    content:
        '在「超展开 → 屏蔽规则」中可以屏蔽指定用户的发言。'
        '被屏蔽用户的帖子、吐槽和评论将不再显示。',
  ),
  TipItem(
    title: '番剧放送时间',
    content:
        '首页「进度」和发现页「每日放送」按星期展示番剧放送时间, '
        '可配合系统日历或桌面组件提醒放送。',
  ),
  TipItem(
    title: '放送日程导出 ICS',
    content:
        '每日放送页面支持导出 ICS 日历文件, 可导入系统日历, '
        '这样就不会错过每周的放送时间。',
  ),
  TipItem(title: '条目取景地标', content: '部分条目详情页展示取景地信息 (Anitabi), 可查看动画中的真实取景地。'),
  TipItem(
    title: '本地 SMB 条目信息整理',
    content:
        '「我的 → 设置 → 本地文件夹」支持连接 SMB 共享文件夹, '
        '按文件夹整理本地番剧与条目信息的对应关系。',
  ),
  TipItem(
    title: 'Webhook 文档',
    content:
        '应用支持 Webhook 推送收藏变化等事件, 可在「Webhook 设置」中添加'
        '自定义回调地址, 配合自动化工作流使用。',
  ),
];

/// 使用技巧 (移植自原项目 screens/web-view/tips)
/// 路由: /tips
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('特色功能'),
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternalUrl(kZhinanHost),
          ),
        ],
      ),

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kTips.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tip = kTips[index];
          return Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              title: Text(
                tip.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.content,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
