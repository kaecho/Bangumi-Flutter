import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../shared/models/subject.dart';


import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';



/// 详情 (原版 HeaderV2 title = params.name || 详情)
/// 路由: /subject/:id/info
class SubjectInfoScreen extends ConsumerStatefulWidget {
  final int id;

  const SubjectInfoScreen({super.key, required this.id});

  @override
  ConsumerState<SubjectInfoScreen> createState() => _SubjectInfoScreenState();
}

class _SubjectInfoScreenState extends ConsumerState<SubjectInfoScreen> {
  String _type = '简介';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final detail = ref.watch(subjectDetailProvider(id));
    final name = detail.valueOrNull?.subject.displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(name, '详情'),
        showBackButton: true,
      ),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(subjectDetailProvider(id))),
        data: (value) {
          final store = ref.watch(settingsStoreProvider);
          final rows = store.subjectPromoteAlias
              ? promoteAliasRows(value.infobox, keyOf: (Infobox e) => e.key)
              : value.infobox;
          final isSummary = _type == '简介';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BgmSegmented<String>(
                  values: const [('简介', '简介'), ('详情', '详情')],
                  selected: _type,
                  onSelect: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(height: 12),
              if (isSummary)
                if (value.subject.summary.isNotEmpty)
                  Text(
                    value.subject.summary.replaceAll('\r\n', '\n').trim(),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  )
                else
                  const Empty(text: '暂无简介')
              else if (rows.isNotEmpty)
                for (final item in rows) _InfoboxRow(item: item)
              else
                const Empty(text: '暂无详情'),
            ],
          );
        },
      ),
    );
  }
}



class _InfoboxRow extends StatelessWidget {
  final Infobox item;
  const _InfoboxRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              item.key,
              style: context.ds.label.copyWith(color: context.ds.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              item.valueText,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
