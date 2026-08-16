import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/settings_store.dart';

import '../../shared/models/collection.dart';
import '../../shared/widgets/score.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';
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
    _privacy = current?.privacy ?? SettingsStore.instance.collectionPrivacy;
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
                Text('收藏管理', style: context.ds.section),
                const Spacer(),
                BgmHeaderAction(
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
                      child: BgmFilterChip(
                        label: CollectionStatus.text(
                          status,
                        ).replaceAll('看', verb),
                        selected: _type == status,
                        onTap: () => setState(() => _type = status),
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
                GestureDetector(
                  onTap: () => setState(() => _rate = 0),
                  child: Text('清除', style: context.ds.caption),
                ),
              ],
            ),
            BgmSlider(
              value: _rate,
              max: 10,
              divisions: 10,
              label: '${_rate.round()}',
              onChanged: (v) => setState(() => _rate = v),
            ),
            BgmField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              hintText: '吐槽 (可选)',
            ),
            const SizedBox(height: 12),
            BgmField(controller: _tagsController, hintText: '标签, 用空格分隔 (可选)'),
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
                        child: Text(
                          h,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  GestureDetector(
                    onTap: _submitting ? null : _remove,
                    child: Text(
                      '删除收藏',
                      style: context.ds.caption.copyWith(
                        color: context.ds.error,
                      ),
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _privacy = _privacy == 1 ? 0 : 1),
                  child: Text(
                    _privacy == 1 ? '私密' : '公开',
                    style: context.ds.caption.copyWith(
                      color: context.ds.accent,
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                BgmButton(
                  '保存',
                  expand: false,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
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
        showBgmToast(context, '收藏已更新', duration: const Duration(seconds: 1));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showBgmToast(context, '保存失败: ${apiErrorMessage(e)}');
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
        showBgmToast(context, '已删除收藏', duration: const Duration(seconds: 1));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showBgmToast(context, '删除失败: ${apiErrorMessage(e)}');
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
  return showBgmSheet<void>(
    context: context,
    builder: (_) => CollectionSheet(subjectId: subjectId),
  );
}
