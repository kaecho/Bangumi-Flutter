import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/cover.dart';

import '../../shared/widgets/loading.dart';

import '../../shared/widgets/app_bar.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 圣殿列表 (最近圣殿)
class TinygrailTemplesScreen extends ConsumerWidget {
  const TinygrailTemplesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(templesProvider);
    return Scaffold(
      appBar: const BgmAppBar(title: '最新圣殿'),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(templesProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无圣殿')
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final cover = (item.cover.isNotEmpty
                            ? item.cover
                            : item.avatar)
                        .replaceFirst('//', 'https://');
                    return GestureDetector(
                      onTap: () =>
                          context.push('/tinygrail/chara/${item.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Cover(
                              url: cover,
                              width: double.infinity,
                              height: double.infinity,
                              radius: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${item.nickname} · Lv.${item.level}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

final templesProvider = FutureProvider<List<TinygrailTemple>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchTempleLast();
});
