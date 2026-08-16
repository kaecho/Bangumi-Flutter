import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'user_models.dart';
import 'user_screen.dart';

/// 原版 NUM_COLUMNS / NUMBER_OF_LINES / SUB_TITLE / ORDER_DS
const kMilestoneColumns = ['2', '3', '4', '5'];
const kMilestoneLines = ['无', '1', '2', '3'];
const kMilestoneSubTitles = ['无', '序号', '时间', '评分', '描述'];
const kMilestoneOrders = ['时间', '评价', '发布'];
const kMilestoneScores = [
  '全部',
  '10',
  '9',
  '8',
  '7',
  '6',
  '5',
  '4',
  '3',
  '2',
  '1',
  '未评分',
  '9-10',
  '7-8',
  '4-6',
  '1-3',
];

class MilestoneQuery {
  final String userId;
  final String subjectType;
  final int status;

  const MilestoneQuery(this.userId, this.subjectType, this.status);

  @override
  bool operator ==(Object other) =>
      other is MilestoneQuery &&
      other.userId == userId &&
      other.subjectType == subjectType &&
      other.status == status;

  @override
  int get hashCode => Object.hash(userId, subjectType, status);
}

final milestoneProvider =
    FutureProvider.family<List<CollectionItem>, MilestoneQuery>((
      ref,
      query,
    ) async {
      final client = ref.read(apiClientProvider);
      final types = query.subjectType == 'all'
          ? kUserTypeTabs.map((e) => e.$1)
          : [query.subjectType];
      final items = <CollectionItem>[];
      for (final type in types) {
        try {
          final data = await client.get(
            apiV0UsersCollections(
              query.userId,
              '${v0SubjectTypeInt(type)}',
              100,
              0,
              '${query.status}',
            ),
          );
          items.addAll(
            UserCollection.fromJson(data as Map<String, dynamic>).data,
          );
        } catch (_) {}
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

/// 照片墙 (原版无 HeaderV2, 筛选 + 设置层)
class MilestoneScreen extends ConsumerStatefulWidget {
  final String userId;

  const MilestoneScreen({super.key, required this.userId});

  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen> {
  String _subjectType = 'all';
  int _status = CollectionStatus.collect;
  String _order = '时间';
  String _score = '全部';
  String _tag = '';
  int _columns = 4;
  int _titleLines = 0;
  String _subTitle = '无';
  bool _reverse = false;
  bool _nsfw = true;

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

  MilestoneQuery get _query =>
      MilestoneQuery(widget.userId, _subjectType, _status);

  List<CollectionItem> _filter(List<CollectionItem> items) {
    var next = [
      for (final item in items)
        if (_nsfw || !item.subject.nsfw) item,
    ];
    if (_tag.isNotEmpty) {
      next = [
        for (final item in next)
          if (item.tags.contains(_tag)) item,
      ];
    }
    next = [
      for (final item in next)
        if (_matchScore(item.rate)) item,
    ];

    next.sort((a, b) {
      final cmp = switch (_order) {
        '评价' => a.rate.compareTo(b.rate),
        '发布' => a.subject.airDate.compareTo(b.subject.airDate),
        _ => a.updatedAt.compareTo(b.updatedAt),
      };
      return _reverse ? cmp : -cmp;
    });
    return next;
  }

  bool _matchScore(int rate) {
    return switch (_score) {
      '全部' => true,
      '未评分' => rate == 0,
      '9-10' => rate >= 9,
      '7-8' => rate == 7 || rate == 8,
      '4-6' => rate >= 4 && rate <= 6,
      '1-3' => rate >= 1 && rate <= 3,
      _ => '$rate' == _score,
    };
  }

  String _subtitleOf(CollectionItem item, int index) {
    return switch (_subTitle) {
      '序号' => '${index + 1}',
      '时间' => item.updatedAt,
      '评分' => item.rate == 0 ? '未评分' : '★ ${item.rate}',
      '描述' => item.comment,
      _ => '',
    };
  }

  Future<void> _openOptions() async {
    await showBgmSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '照片墙',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('此页面可一览用户收藏，可配合手机自带的长截屏使用。'),
              const SizedBox(height: 12),
              BgmSettingRow(
                title: '用户 ID 直达',
                below: BgmField(
                  hintText: '可输入用户 ID 直达',
                  onSubmitted: (value) {
                    final id = value.trim();
                    if (id.isEmpty) return;
                    Navigator.pop(context);
                    context.pushReplacement('/user/$id/milestone');
                  },
                ),
              ),
              BgmSettingRow(
                title: '列数',
                trailing: BgmSelect<String>(
                  value: '$_columns',
                  items: [for (final n in kMilestoneColumns) (n, n)],
                  onChanged: (v) => _saveColumns(int.parse(v)),
                ),
              ),
              BgmSettingRow(
                title: '标题行数',
                trailing: BgmSelect<String>(
                  value: _titleLines == 0 ? '无' : '$_titleLines',
                  items: [for (final n in kMilestoneLines) (n, n)],
                  onChanged: (v) =>
                      setState(() => _titleLines = v == '无' ? 0 : int.parse(v)),
                ),
              ),
              BgmSettingRow(
                title: '第二行',
                trailing: BgmSelect<String>(
                  value: _subTitle,
                  items: [for (final n in kMilestoneSubTitles) (n, n)],
                  onChanged: (v) => setState(() => _subTitle = v),
                ),
              ),
              BgmSettingRow(
                title: '倒序',
                trailing: BgmSwitch(
                  value: _reverse,
                  onChanged: (v) => setState(() => _reverse = v),
                ),
              ),
              BgmSettingRow(
                title: '显示 NSFW',
                trailing: BgmSwitch(
                  value: _nsfw,
                  onChanged: (v) => setState(() => _nsfw = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(milestoneProvider(_query));
    final action = SubjectType.action(
      _subjectType == 'all' ? 'anime' : _subjectType,
    );
    final tags =
        ref
            .watch(
              myCollectionTagsProvider((
                userId: widget.userId,
                type: _subjectType == 'all' ? 'anime' : _subjectType,
                status: _status,
              )),
            )
            .valueOrNull ??
        const [];
    final tagItems = userCollectionTagMenuItems(tags, reset: false);
    return Scaffold(
      appBar: BgmAppBar(
        title: '照片墙',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: _subjectType == 'all'
                              ? '全部'
                              : SubjectType.text(_subjectType),
                          items: [
                            ('all', '全部'),
                            for (final t in kUserTypeTabs) t,
                          ],
                          onSelected: (v) => setState(() {
                            _subjectType = v;
                            _tag = '';
                          }),
                        ),
                        const Text(' · '),
                        _FilterChip(
                          label: CollectionStatus.text(
                            _status,
                          ).replaceAll('看', action),
                          items: [
                            for (final t in kCollectionStatusTabs)
                              if (t.$1 != 0)
                                ('${t.$1}', t.$2.replaceAll('看', action)),
                          ],
                          onSelected: (v) => setState(() {
                            _status = int.parse(v);
                            _tag = '';
                          }),
                        ),
                        const Text(' · '),
                        _FilterChip(
                          label: '按$_order',
                          items: [for (final n in kMilestoneOrders) (n, n)],
                          onSelected: (v) => setState(() => _order = v),
                        ),
                        const Text(' · '),
                        _FilterChip(
                          label: userCollectionTagLabel(_tag),
                          items: [for (final n in tagItems) (n, n)],
                          onSelected: (v) => setState(
                            () => _tag = parseUserCollectionTagSelect(v),
                          ),
                        ),
                        const Text(' · '),
                        _FilterChip(
                          label: _score == '全部' ? '评分' : '★ $_score',
                          items: [for (final n in kMilestoneScores) (n, n)],
                          onSelected: (v) => setState(() => _score = v),
                        ),
                      ],
                    ),
                  ),
                ),
                BgmHeaderAction(
                  tooltip: '设置',
                  icon: const Icon(Icons.settings, size: 18),
                  onPressed: _openOptions,
                ),
              ],
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Loading(),
        error: (_, _) =>
            BgmRetry(onRetry: () => ref.invalidate(milestoneProvider(_query))),
        data: (raw) {
          final items = _filter(raw);
          if (items.isEmpty) return const Center(child: Text('暂无收藏'));
          final width = MediaQuery.of(context).size.width / _columns;
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: _titleLines == 0 && _subTitle == '无'
                  ? 0.72
                  : 0.58,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final subtitle = _subtitleOf(item, index);
              return GestureDetector(
                onTap: () => context.push('/subject/${item.subject.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Cover(
                        url: item.subject.images.common,
                        width: width,
                        height: width * 1.4,
                        radius: 0,
                      ),
                    ),
                    if (_titleLines > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Text(
                          item.subject.displayName,
                          maxLines: _titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(value: item.$1, child: Text(item.$2)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
