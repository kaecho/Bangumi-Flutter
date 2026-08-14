import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 照片墙数据: 全部类型"看过"的条目封面
final milestoneProvider = FutureProvider.family<List<CollectionItem>, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final items = <CollectionItem>[];
  for (final type in kUserTypeTabs) {
    try {
      final data = await client.get(
        apiV0UsersCollections(userId, '${v0SubjectTypeInt(type.$1)}', 100, 0, '2'),
      );
      items.addAll(UserCollection.fromJson(data as Map<String, dynamic>).data);
    } catch (_) {
      // 单个类型失败不阻塞整体
    }
  }
  return items;
});

/// 我的照片墙 (发现页菜单入口, 原项目 Milestone)
class MyMilestoneScreen extends ConsumerWidget {
  const MyMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return me == null
        ? const Scaffold(body: Center(child: Text('请先登录')))
        : MilestoneScreen(userId: userPathId(me));
  }
}

/// 照片墙 (用户"看过"条目封面拼图)
class MilestoneScreen extends ConsumerStatefulWidget {
  final String userId;

  const MilestoneScreen({super.key, required this.userId});

  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen> {
  int _columns = 4;

  static const _kColumnsKey = 'user_grid_num';

  @override
  void initState() {
    super.initState();
    _restoreColumns();
  }

  Future<void> _restoreColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kColumnsKey);
    if (!mounted) return;
    setState(() => _columns = v ?? 4);
  }

  Future<void> _saveColumns(int value) async {
    setState(() => _columns = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColumnsKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(milestoneProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('照片墙'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _columns,
            onSelected: _saveColumns,
            itemBuilder: (context) => [
              for (final n in [3, 4, 5, 6])
                PopupMenuItem(value: n, child: Text('$n 列')),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => const Loading(),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败'),
              TextButton(
                onPressed: () => ref.invalidate(milestoneProvider(widget.userId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('暂无看过条目'));
          final width = MediaQuery.of(context).size.width / _columns;
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => context.push('/subject/${item.subject.id}'),
                child: Cover(
                  url: item.subject.images.common,
                  width: width,
                  height: width * 1.4,
                  radius: 0,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
