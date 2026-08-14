import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/recommend_list.dart';

/// 推荐 (AI 推荐)
///
/// 原项目调用第三方推荐服务 POST https://cf.bangrecs.net/api/v4/rec/{uid}
/// (该服务当前不可达), 这里使用与 [LikeScreen] 相同的官方数据等价实现:
/// 基于用户收藏的客户端推荐评分。
class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen> {
  int _type = 2;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: 'AI 推荐',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'tips') {
                context.push('/tips');
              } else if (value == 'topic') {
                context.push('/rakuen/topic/group/382655');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tips', child: Text('说明')),
              PopupMenuItem(value: 'topic', child: Text('帖子讨论')),
            ],
          ),
        ],
      ),

      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登录后获取个性化推荐'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.push('/login'),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final (value, label) in kRecommendTypes)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tag(
                            text: label,
                            active: _type == value,
                            onTap: () => setState(() => _type = value),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: RecommendList(subjectType: _type)),
              ],
            ),
    );
  }
}
