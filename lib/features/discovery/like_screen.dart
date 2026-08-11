import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/recommend_list.dart';

/// 类型 Tab (v0 subject_type 数字)
const kRecommendTypes = [
  (2, '动画'),
  (1, '书籍'),
  (4, '游戏'),
  (3, '音乐'),
  (6, '三次元'),
];

/// 猜你喜欢
///
/// 原项目以用户收藏为数据源做客户端推荐评分, 本页移植该逻辑:
/// v0 收藏 API → 客户端评分 → 降序列表。
class LikeScreen extends ConsumerStatefulWidget {
  const LikeScreen({super.key});

  @override
  ConsumerState<LikeScreen> createState() => _LikeScreenState();
}

class _LikeScreenState extends ConsumerState<LikeScreen> {
  int _type = 2;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '猜你喜欢', showBackButton: true),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('此功能依赖收藏数据, 请先登录'),
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
