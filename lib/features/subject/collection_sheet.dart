import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/collection.dart';
import 'subject_providers.dart';

/// 收藏管理底部弹窗
///
/// 状态选择 + 评分 + 吐槽 + 标签, 保存后 POST /collection/{id}/update
class CollectionSheet extends ConsumerStatefulWidget {
  final int subjectId;

  const CollectionSheet({super.key, required this.subjectId});

  @override
  ConsumerState<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<CollectionSheet> {
  late int _type;
  late double _rate;
  late final TextEditingController _commentController;
  late final TextEditingController _tagsController;
  bool _submitting = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(collectionProvider(widget.subjectId)).valueOrNull;
    _type = current?.type ?? 0;
    _rate = (current?.rate ?? 0).toDouble();
    _commentController = TextEditingController(text: current?.comment ?? '');
    _tagsController = TextEditingController(text: current?.tags.join(' ') ?? '');
    _loaded = true;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCollection = _type > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('收藏管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 状态选择
            Row(
              children: [
                for (final status in const [1, 2, 3, 4, 5])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(
                          CollectionStatus.text(status),
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _type == status,
                        onSelected: (_) => setState(() => _type = status),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 评分
            Row(
              children: [
                Text(
                  _rate > 0 ? '评分: ${_rate.round()}' : '评分: 未评分',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 8),
                Stars(score: _rate, size: 14),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _rate = 0),
                  child: const Text('清除', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Slider(
              value: _rate,
              max: 10,
              divisions: 10,
              label: '${_rate.round()}',
              onChanged: (v) => setState(() => _rate = v),
            ),
            // 吐槽
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '吐槽 (可选)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // 标签
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: '标签, 用空格分隔 (可选)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasCollection) ...[
                  TextButton(
                    onPressed: _submitting ? null : _remove,
                    child: Text(
                      '删除收藏',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final tags = _tagsController.text
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      await updateCollectionAction(
        ref,
        widget.subjectId,
        type: _type,
        rate: _rate.round(),
        comment: _commentController.text.trim(),
        tags: tags,
      );
      invalidateSubjectState(ref, widget.subjectId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏已更新'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${apiErrorMessage(e)}')),
        );
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _submitting = true);
    try {
      await removeCollectionAction(ref, widget.subjectId);
      invalidateSubjectState(ref, widget.subjectId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除收藏'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${apiErrorMessage(e)}')),
        );
      }
    }
  }
}
