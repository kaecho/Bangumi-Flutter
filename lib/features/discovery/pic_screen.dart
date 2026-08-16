import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/subject.dart' hide Tag;
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';

import 'widgets/discovery_html.dart';
import 'widgets/recommend_list.dart';

/// 照片墙: 用户收藏条目封面网格
///
/// 原项目为第三方图站 (bobopic) 抓取, 按任务约定移植为用户收藏
/// 封面的照片墙 (v0 收藏 API)。
final picProvider = FutureProvider.family<List<Subject>, int>((
  ref,
  subjectType,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final userId = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);
  final items = <Subject>[];
  for (final status in const [2, 3, 1]) {
    try {
      final data = await client.get(
        apiV0UsersCollections(userId, '$subjectType', 100, 0, '$status'),
      );
      items.addAll(parseV0Collections(data).map((e) => e.subject));
    } catch (_) {}
  }
  return items;
});

class PicScreen extends ConsumerStatefulWidget {
  const PicScreen({super.key});

  @override
  ConsumerState<PicScreen> createState() => _PicScreenState();
}

class _PicScreenState extends ConsumerState<PicScreen> {
  int _type = 2;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final subjects = ref.watch(picProvider(_type));
    return Scaffold(
      appBar: BgmAppBar(
        title: '图集',

        showBackButton: true,
        actions: [
          PopupMenuButton<int>(
            tooltip: '筛选',
            padding: EdgeInsets.zero,
            onSelected: (value) => setState(() => _type = value),
            itemBuilder: (_) => [
              for (final (value, label) in kRecommendTypes)
                PopupMenuItem(
                  value: value,
                  child: Text(_type == value ? '· $label' : label),
                ),
            ],
            child: Icon(
              Icons.filter_list,
              size: 20,
              color: _type == 2 ? null : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),

      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登录后查看收藏照片墙'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '去登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : subjects.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) =>
                  BgmRetry(onRetry: () => ref.invalidate(picProvider(_type))),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('暂无收藏'))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(picProvider(_type).future),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 3 / 4,
                            ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final subject = list[index];
                          return GestureDetector(
                            onTap: () => context.push('/subject/${subject.id}'),
                            child: Cover(
                              url: subject.images.medium,
                              width: double.infinity,
                              height: double.infinity,
                              radius: 6,
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }
}
