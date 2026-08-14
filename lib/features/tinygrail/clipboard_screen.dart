import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 剪贴板 (粘贴角色 ID 批量直达)
class TinygrailClipboardScreen extends ConsumerStatefulWidget {
  const TinygrailClipboardScreen({super.key});

  @override
  ConsumerState<TinygrailClipboardScreen> createState() =>
      _TinygrailClipboardScreenState();
}

class _TinygrailClipboardScreenState
    extends ConsumerState<TinygrailClipboardScreen> {
  List<int> _ids = const [];
  bool _loading = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final content = data?.text ?? '';
    final ids = RegExp(r'\d+')
        .allMatches(content)
        .map((m) => int.tryParse(m.group(0) ?? ''))
        .whereType<int>()
        .where((id) => id > 100)
        .toList();
    setState(() {
      _ids = ids;
      _loading = true;
    });
    if (ids.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      await ref.read(tinygrailApiProvider).fetchCharaByIds(ids);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clipboardProvider(_ids));
    return Scaffold(
      appBar: AppBar(
        title: const Text('粘贴板'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _paste,
          ),
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _ids.join(',')));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制角色 ID')));
            },
          ),
        ],
      ),

      body: _ids.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('从剪贴板粘贴角色 ID 列表'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.paste),
                    label: const Text('读取剪贴板'),
                  ),
                ],
              ),
            )
          : _loading
          ? const Loading(height: double.infinity)
          : async.when(
              loading: () => const Loading(height: double.infinity),
              error: (_, _) => const Center(child: Text('加载失败')),
              data: (list) => ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => CharaTile(
                  chara: list[index],
                  onTap: () =>
                      context.push('/tinygrail/chara/${list[index].id}'),
                ),
              ),
            ),
    );
  }
}

final clipboardProvider =
    FutureProvider.family<List<TinygrailChara>, List<int>>((ref, ids) async {
      if (ids.isEmpty) return const [];
      return ref.read(tinygrailApiProvider).fetchCharaByIds(ids);
    });
