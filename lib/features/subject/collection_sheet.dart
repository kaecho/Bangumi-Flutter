import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/settings_store.dart';

import '../../shared/models/collection.dart';
import '../../shared/widgets/score.dart';
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
  int _privacy = 0;

  @override
  void initState() {
    super.initState();
    final current = ref.read(collectionProvider(widget.subjectId)).valueOrNull;
    _type = current?.type ?? 0;
    _rate = (current?.rate ?? 0).toDouble();
    _commentController = TextEditingController(text: current?.comment ?? '');
    _tagsController = TextEditingController(
      text: current?.tags.join(' ') ?? '',
    );
    _privacy = SettingsStore.instance.collectionPrivacy;
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
    final subjectType =
        ref
            .watch(subjectDetailProvider(widget.subjectId))
            .valueOrNull
            ?.subject
            .type ??
        'anime';
    final verb = SubjectType.action(subjectType);
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
                const Text(
                  '收藏管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final status in const [1, 2, 3, 4, 5])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(
                          CollectionStatus.text(status).replaceAll('看', verb),
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
            if (SettingsStore.instance.collectionCommentHistory.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: '吐槽历史',
                  onSelected: (v) => _commentController.text = v,
                  itemBuilder: (_) => [
                    for (final h
                        in SettingsStore.instance.collectionCommentHistory)
                      PopupMenuItem(
                        value: h,
                        child: Text(h, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  child: Text(
                    '吐槽历史',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasCollection) ...[
                  TextButton(
                    onPressed: _submitting ? null : _remove,
                    child: Text(
                      '删除收藏',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _privacy = _privacy == 1 ? 0 : 1),
                  child: Text(_privacy == 1 ? '私密' : '公开'),
                ),
                const SizedBox(width: 8),
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
      final comment = _commentController.text.trim();
      await updateCollectionAction(
        ref,
        widget.subjectId,
        type: _type,
        rate: _rate.round(),
        comment: comment,
        tags: tags,
        privacy: _privacy,
      );
      await SettingsStore.instance.setCollectionPrivacy(_privacy);
      await SettingsStore.instance.pushCollectionComment(comment);

      invalidateSubjectState(ref, widget.subjectId);
      SettingsStore.instance.haptic(2);
      await _maybeAutoComplete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('收藏已更新'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: ${apiErrorMessage(e)}')));
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
          const SnackBar(
            content: Text('已删除收藏'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: ${apiErrorMessage(e)}')));
      }
    }
  }

  Future<void> _maybeAutoComplete() async {
    if (_type != CollectionStatus.collect) return;
    final store = SettingsStore.instance;
    final subject = ref
        .read(subjectDetailProvider(widget.subjectId))
        .valueOrNull
        ?.subject;
    if (subject == null) return;
    final eps = subject.eps > 0 ? subject.eps : subject.epsCount;
    if (store.autoCompleteEps &&
        (subject.type == SubjectType.anime ||
            subject.type == SubjectType.real) &&
        eps > 0) {
      await updateWatchedEpsAction(ref, widget.subjectId, eps);
      ref.invalidate(epStatusProvider(widget.subjectId));
      return;
    }
    if (store.autoCompleteBooks && subject.type == SubjectType.book) {
      await updateWatchedEpsAction(
        ref,
        widget.subjectId,
        eps,
        watchedVols: subject.volums > 0 ? subject.volums : null,
      );
      ref.invalidate(epStatusProvider(widget.subjectId));
    }
  }
}

/// 打开原版 Manage 等价的收藏弹层
Future<void> showCollectionSheet(BuildContext context, int subjectId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CollectionSheet(subjectId: subjectId),
  );
}
