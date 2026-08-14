import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_notes.dart';

/// 我的道具
class TinygrailItemsScreen extends ConsumerWidget {
  const TinygrailItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的道具'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onSelected: (name) => context.push(tinygrailItemNotePath(name)),
            itemBuilder: (_) => [
              for (final name in kTinygrailItemNoteNames)
                PopupMenuItem(value: name, child: Text(name)),
            ],
          ),
        ],
      ),

      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('请先登录')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(itemsProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无道具')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      leading: _ItemIcon(name: item.name),
                      title: Text(item.name),
                      subtitle: Text(
                        item.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        'x${item.amount}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  final String name;

  const _ItemIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final itemsProvider = FutureProvider<List<TinygrailItems>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchItems();
});
