import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 收藏的人物 (角色/人物, bgm.tv/user/{uid}/mono/{kind}, 主站 HTML)
final userMonoProvider =
    FutureProvider.family<List<UserMono>, ({String userId, String kind})>(
        (ref, arg) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserMonoHtml(arg.userId, kind: arg.kind), host: kHost);
  return parseUserMono(html as String);
});

/// 我的人物 (当前登录用户收藏的角色/人物)
class MyMonoScreen extends ConsumerStatefulWidget {
  const MyMonoScreen({super.key});

  @override
  ConsumerState<MyMonoScreen> createState() => _MyMonoScreenState();
}

class _MyMonoScreenState extends ConsumerState<MyMonoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的人物'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '角色'), Tab(text: '人物')],
        ),
      ),
      body: me == null
          ? const Center(child: Text('请先登录'))
          : TabBarView(
              controller: _tab,
              children: [
                _MonoList(userId: userPathId(me), kind: 'character'),
                _MonoList(userId: userPathId(me), kind: 'person'),
              ],
            ),
    );
  }
}

class _MonoList extends ConsumerWidget {
  final String userId;
  final String kind;

  const _MonoList({required this.userId, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userMonoProvider((userId: userId, kind: kind)));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (monos) {
        if (monos.isEmpty) return const Center(child: Text('暂无收藏'));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: monos.length,
          itemBuilder: (context, index) {
            final mono = monos[index];
            return InkWell(
              onTap: () => context.push('/mono/${mono.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(url: mono.avatar, width: double.infinity, height: 110, radius: 6),
                  const SizedBox(height: 4),
                  Text(
                    mono.name,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
