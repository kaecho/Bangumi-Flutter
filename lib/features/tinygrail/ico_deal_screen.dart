import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 新股交易 (ICO 详情: 注资 + 参与者)
class TinygrailIcoDealScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailIcoDealScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(icoDealProvider(monoId));
    return Scaffold(
      appBar: AppBar(title: const Text('新股交易')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (data) {
          final chara = data.$1;
          final initial = data.$2;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(chara.name.isEmpty ? '?' : chara.name.characters.first)),
                  title: Text(chara.name),
                  subtitle: Text(
                    '发行价 ¥${tgPrice(chara.price)} · 发行量 ${tgAmount(chara.total)} · 参与者 ${chara.users}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('注资 ICO', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _JoinButton(icoId: chara.icoId == 0 ? chara.id : chara.icoId, monoId: monoId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('初始股份', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (initial.isEmpty)
                        const Text('暂无参与者', style: TextStyle(fontSize: 12))
                      else
                        for (final item in initial)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${item.nickName.isEmpty ? item.name : item.nickName} · ${tgAmount(item.amount)} 股 · ${friendlyTime(item.begin)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JoinButton extends ConsumerStatefulWidget {
  final int icoId;
  final int monoId;

  const _JoinButton({required this.icoId, required this.monoId});

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _loading = false;

  Future<void> _join() async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => const _JoinDialog(),
    );
    if (amount == null || amount <= 0) return;
    setState(() => _loading = true);
    try {
      final ok = await ref.read(tinygrailApiProvider).doJoin(widget.icoId, amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '注资成功' : '注资失败')),
      );
      ref.invalidate(icoDealProvider(widget.monoId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('注资失败: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _join,
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('参与注资 (≥5000)'),
      ),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _controller = TextEditingController(text: '5000');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('注资'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '金额 (≥5000)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_controller.text) ?? 0),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

final icoDealProvider =
    FutureProvider.family<({TinygrailChara chara, List<TinygrailInitial> initial}), int>(
        (ref, monoId) async {
  final api = ref.read(tinygrailApiProvider);
  final chara = await api.fetchChara(monoId);
  final icoId = chara.icoId == 0 ? chara.id : chara.icoId;
  List<TinygrailInitial> initial = const [];
  try {
    initial = await api.fetchInitial(icoId, 1);
  } catch (_) {}
  return (chara: chara, initial: initial);
});
