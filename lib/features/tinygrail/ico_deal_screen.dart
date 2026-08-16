import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
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
      appBar: const BgmAppBar(title: 'ICO'),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (data) {
          final chara = data.chara;
          final initial = data.initial;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              BgmTextRow(
                title: chara.name,
                subtitle:
                    '发行价 ¥${tgPrice(chara.price)} · 发行量 ${tgAmount(chara.total)} · 参与者 ${chara.users}',
              ),
              const SizedBox(height: 8),
              BgmCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '注资 ICO',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _JoinButton(
                      icoId: chara.icoId == 0 ? chara.id : chara.icoId,
                      monoId: monoId,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              BgmCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '初始股份',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
      final ok = await ref
          .read(tinygrailApiProvider)
          .doJoin(widget.icoId, amount);
      if (!mounted) return;
      showBgmToast(context, ok ? '注资成功' : '注资失败');
      ref.invalidate(icoDealProvider(widget.monoId));
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '注资失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BgmButton(
      '参与注资 (≥5000)',
      loading: _loading,
      onPressed: _loading ? null : _join,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: BgmDialog(
        title: '注资',
        content: BgmField(
          controller: _controller,
          keyboardType: TextInputType.number,
          labelText: '金额 (≥5000)',
        ),
        actions: [
          BgmButton(
            '取消',
            type: BgmButtonType.plain,
            expand: false,
            onPressed: () => Navigator.pop(context),
          ),
          BgmButton(
            '确认',
            expand: false,
            onPressed: () =>
                Navigator.pop(context, int.tryParse(_controller.text) ?? 0),
          ),
        ],
      ),
    );
  }
}

final icoDealProvider =
    FutureProvider.family<
      ({TinygrailChara chara, List<TinygrailInitial> initial}),
      int
    >((ref, monoId) async {
      final api = ref.read(tinygrailApiProvider);
      final chara = await api.fetchChara(monoId);
      final icoId = chara.icoId == 0 ? chara.id : chara.icoId;
      List<TinygrailInitial> initial = const [];
      try {
        initial = await api.fetchInitial(icoId, 1);
      } catch (_) {}
      return (chara: chara, initial: initial);
    });
