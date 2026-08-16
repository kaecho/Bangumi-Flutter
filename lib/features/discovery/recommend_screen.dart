import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/recommend_list.dart';

const kRecommendCategoryOptions = <(int, String)>[
  (0, '默认'),
  ...kRecommendTypes,
];

String recommendCategoryLabel(int type) {
  for (final (value, label) in kRecommendCategoryOptions) {
    if (value == type) return label;
  }
  return '默认';
}

/// 原版 recommend Header DATA
const kRecommendMoreItems = <(String, String)>[
  ('tips', '说明'),
  ('topic', '帖子讨论'),
];

/// 推荐 (AI 推荐)
///
/// 原项目调用第三方推荐服务 POST https://cf.bangrecs.net/api/v4/rec/{uid}
/// (该服务当前不可达), 这里使用与 [LikeScreen] 相同的官方数据等价实现:
/// 基于用户收藏的客户端推荐评分。搜索框按用户 ID 进空间。
class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen> {
  int _type = 0;
  final _userId = TextEditingController();

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  int get _subjectType => _type == 0 ? 2 : _type;

  void _openUser() {
    final id = _userId.text.trim();
    if (id.isEmpty) return;
    context.push('/user/$id');
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final ds = context.ds;
    return Scaffold(
      appBar: BgmAppBar(
        title: 'AI 推荐',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: kRecommendMoreItems,

            onSelected: (value) {
              if (value == 'tips') {
                context.push('/tips');
              } else if (value == 'topic') {
                context.push('/rakuen/topic/group/382655');
              }
            },
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
                  BgmButton(
                    '去登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      PopupMenuButton<int>(
                        tooltip: '分类',
                        padding: EdgeInsets.zero,
                        onSelected: (v) => setState(() => _type = v),
                        itemBuilder: (_) => [
                          for (final (value, label)
                              in kRecommendCategoryOptions)
                            PopupMenuItem(value: value, child: Text(label)),
                        ],
                        child: Container(
                          width: 68,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ds.accentSoft,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(34),
                            ),
                            border: Border.all(
                              color: ds.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            recommendCategoryLabel(_type),
                            style: ds.label.copyWith(
                              color: ds.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _userId,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _openUser(),
                            decoration: InputDecoration(
                              hintText: '输入用户 ID',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: ds.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: ds.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: ds.accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openUser,
                        child: Container(
                          width: 68,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ds.surfaceCard,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: ds.border),
                          ),
                          child: Text(
                            '查询',
                            style: ds.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: RecommendList(subjectType: _subjectType)),
              ],
            ),
    );
  }
}
