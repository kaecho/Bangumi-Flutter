import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/horizontal_mask.dart';

import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';
import '../progress/progress_screen.dart';
import '../subject/collection_sheet.dart';
import 'calendar_notes.dart';
import '../../shared/widgets/bgm_button.dart';

/// 原版日历顶栏 DATA + toolBar
List<(String, String)> calendarMoreItems({
  required bool listLayout,
  required bool collectedOnly,
  required bool expandUnknown,
}) => [
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
  ('info', '补充说明'),
  ('layout', '布　局〔${listLayout ? '列表' : '网格'}〕'),
  ('favor', '收　藏〔${collectedOnly ? '只显示' : '显示'}〕'),
  ('unknown', '未知时间番剧〔${expandUnknown ? '显示' : '不显示'}〕'),
];

/// 每日放送
///
/// 数据来源:
/// - GET /calendar — 一周 7 天的条目分组
/// - bangumi-data 放送时间表 (https://bangumi-data.github.io/bangumi-data/data.json,
///   与原项目 protobuf 版 bangumi-data 同源) — 每条目的放送时间
/// 放送时间表获取失败时仅不显示时间, 不影响条目列表。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _adapt = '全部';
  String _tag = '全部';
  String _studio = '全部';
  bool _listLayout = false;
  bool _collectedOnly = false;
  bool _expandUnknown = false;
  final _scroll = ScrollController();

  String _filterValue(String raw) {
    if (raw == '全部' || raw.isEmpty) return '全部';
    return raw.split(' (').first;
  }

  bool _match(Subject s, {required bool collected}) {
    if (_collectedOnly && !collected) return false;
    if (SettingsStore.instance.filter18x &&
        isSensitiveSubject(
          nsfw: s.nsfw,
          name: s.name,
          nameCn: s.nameCn,
          extra: s.summary,
        )) {
      return false;
    }
    final names = [for (final t in s.tags) t.name];
    if (_adapt != '全部' && !names.contains(_adapt)) return false;
    if (_tag != '全部' && !names.contains(_tag)) return false;
    if (_studio != '全部' && !names.contains(_studio)) return false;
    return true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(calendarProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '每日放送',
        showBackButton: true,
        actions: [
          if (SettingsStore.instance.exportICS)
            BgmHeaderAction(
              tooltip: '导出 ICS',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => _exportWeekIcs(context, ref),
            ),
          if (_listLayout)
            BgmHeaderAction(
              tooltip: '跳到今天',
              icon: const Icon(Icons.radio_button_checked, size: 18),
              onPressed: () => _jumpToday(days.valueOrNull ?? const []),
            ),
          BgmHeaderMore(
            items: calendarMoreItems(
              listLayout: _listLayout,
              collectedOnly: _collectedOnly,
              expandUnknown: _expandUnknown,
            ),
            onSelected: _onMenu,
          ),
        ],
      ),

      body: days.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) =>
            BgmRetry(onRetry: () => ref.invalidate(calendarProvider)),
        data: (list) {
          final filters = calendarFilterOptions(list);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                child: Row(
                  children: [
                    if (filters.adapts.length > 1)
                      _CalFilter(
                        label: _adapt == '全部' ? '改编' : _adapt,
                        options: filters.adapts,
                        selected: _adapt,
                        onSelected: (v) =>
                            setState(() => _adapt = _filterValue(v)),
                      ),
                    if (filters.tags.length > 1) ...[
                      const SizedBox(width: 8),
                      _CalFilter(
                        label: _tag == '全部' ? '标签' : _tag,
                        options: filters.tags,
                        selected: _tag,
                        onSelected: (v) =>
                            setState(() => _tag = _filterValue(v)),
                      ),
                    ],
                    if (filters.studios.length > 1) ...[
                      const SizedBox(width: 8),
                      _CalFilter(
                        label: _studio == '全部' ? '制作' : _studio,
                        options: filters.studios,
                        selected: _studio,
                        onSelected: (v) =>
                            setState(() => _studio = _filterValue(v)),
                      ),
                    ],
                    if (_adapt != '全部' || _tag != '全部' || _studio != '全部')
                      BgmHeaderAction(
                        tooltip: '清除',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _adapt = '全部';
                          _tag = '全部';
                          _studio = '全部';
                        }),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(calendarProvider);
                    ref.invalidate(onAirTimeProvider);
                    await ref.read(calendarProvider.future);
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _DaySection(
                      day: list[index],
                      filter: _match,
                      highlight: [
                        if (_adapt != '全部') _adapt,
                        if (_tag != '全部') _tag,
                        if (_studio != '全部') _studio,
                      ],
                      listLayout: _listLayout,
                      expandUnknown: _expandUnknown,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onMenu(String value) async {
    switch (value) {
      case 'layout':
        setState(() => _listLayout = !_listLayout);
      case 'favor':
        setState(() => _collectedOnly = !_collectedOnly);
      case 'unknown':
        setState(() => _expandUnknown = !_expandUnknown);
      case 'info':
        if (!mounted) return;
        await context.push(calendarNotePath());

      case 'spa':
        await openExternalUrl(htmlSpa('Calendar'));
      case 'browser':
        await openExternalUrl('https://bgm.tv/calendar');
    }
  }

  void _jumpToday(List<CalendarDay> days) {
    if (days.isEmpty || !_scroll.hasClients) return;
    final today = DateTime.now().weekday % 7;
    final index = days.indexWhere((d) => d.weekday % 7 == today);
    if (index < 0) return;
    _scroll.animateTo(
      index * 280.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }
}

class _CalFilter extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CalFilter({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ds.surfaceCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: ds.caption.copyWith(
            color: ds.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  final CalendarDay day;
  final bool Function(Subject s, {required bool collected}) filter;
  final List<String> highlight;
  final bool listLayout;
  final bool expandUnknown;

  const _DaySection({
    required this.day,
    required this.filter,
    this.highlight = const [],
    this.listLayout = false,
    this.expandUnknown = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collections =
        ref.watch(progressProvider('all')).valueOrNull?.items ?? const [];
    final collectionById = {
      for (final item in collections) item.subject.id: item.type,
    };
    final items = day.items
        .where((s) => filter(s, collected: collectionById.containsKey(s.id)))
        .toList();
    // 按放送时间排序 (未知时间排最后)
    var sorted = [...items]
      ..sort((a, b) => _timeOf(ref, a.id).compareTo(_timeOf(ref, b.id)));
    if (!expandUnknown) {
      sorted = [
        for (final subject in sorted)
          if (_timeOf(ref, subject.id) != '99:99') subject,
      ];
    }
    // 同一时间只保留第一个显示
    final shownTimes = <String>{};
    final now = DateTime.now();
    final today = now.weekday % 7;
    final isToday = day.weekday % 7 == today;
    final nowMinutes = now.hour * 60 + now.minute;
    var nowIndex = -1;
    if (isToday && sorted.isNotEmpty) {
      nowIndex = sorted.indexWhere((subject) {
        final time = _timeOf(ref, subject.id);
        if (time.isEmpty || time == '99:99' || !time.contains(':')) {
          return false;
        }
        final parts = time.split(':');
        final minutes =
            (int.tryParse(parts[0]) ?? 99) * 60 +
            (int.tryParse(parts[1]) ?? 99);
        return minutes > nowMinutes;
      });
      if (nowIndex < 0) nowIndex = sorted.length;
    }
    final itemCount = sorted.length + (nowIndex >= 0 ? 1 : 0);

    Widget itemAt(int index) {
      if (nowIndex >= 0 && index == nowIndex) {
        return _CalendarNowLine(
          clock:
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        );
      }
      final subjectIndex = nowIndex >= 0 && index > nowIndex
          ? index - 1
          : index;
      final subject = sorted[subjectIndex];
      final time = _timeOf(ref, subject.id);
      final showTime = time.isNotEmpty && shownTimes.add(time);
      if (listLayout) {
        return _CalendarLine(
          subject: subject,
          time: showTime ? time : '',
          collection: SubjectType.statusText(
            collectionById[subject.id] ?? 0,
            subject.type,
          ),
          highlight: highlight,
        );
      }
      return _CalendarCard(
        subject: subject,
        time: showTime ? time : '',
        collection: SubjectType.statusText(
          collectionById[subject.id] ?? 0,
          subject.type,
        ),
        highlight: highlight,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Text(
                day.cn.isEmpty ? '周${day.weekday}' : day.cn,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(_sectionDate(day.weekday), style: context.ds.caption),
            ],
          ),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text('暂无放送', style: context.ds.caption),
          )
        else if (listLayout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var index = 0; index < itemCount; index++) itemAt(index),
              ],
            ),
          )
        else
          SizedBox(
            height: highlight.isEmpty ? 204 : 220,
            child: HorizontalMask(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => itemAt(index),
              ),
            ),
          ),
      ],
    );
  }

  /// 条目放送时间 'HH:MM', 未知返回 '99:99' 便于排序
  String _timeOf(WidgetRef ref, int subjectId) {
    final table = ref.watch(onAirTimeProvider).valueOrNull;
    if (table == null) return '99:99';
    return table[subjectId] ?? '99:99';
  }

  /// 本周内该星期对应的日期 (MM月DD日)
  String _sectionDate(int weekday) {
    final now = DateTime.now();
    final diff = (weekday - (now.weekday % 7) + 7) % 7;
    final date = now.add(Duration(days: diff));
    return '${date.month}月${date.day}日';
  }
}

class _CalendarCard extends ConsumerWidget {
  final Subject subject;
  final String time;
  final String collection;
  final List<String> highlight;

  const _CalendarCard({
    required this.subject,
    required this.time,
    this.collection = '',
    this.highlight = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rating = subject.rating;
    final hideScore = SettingsStore.instance.hideScore;
    final score = !hideScore && rating != null && rating.score > 0
        ? rating.score.toStringAsFixed(1)
        : '';
    final clock = time.isNotEmpty && time != '99:99' ? time : '';
    final title = subject.displayName;
    final fontSize = visualFontSize(title, const [(18, 10), (14, 11), (0, 11)]);
    final titleStyle = TextStyle(
      fontSize: fontSize,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    final matched = highlight.where((word) {
      final blob =
          '${subject.summary} ${subject.name} ${subject.nameCn} $title';
      return blob.contains(word.replaceAll('改', '')) || blob.contains(word);
    }).toList();

    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () {
        showCollectionSheet(context, subject.id).then((_) {
          ref.invalidate(progressProvider('all'));
        });
      },
      child: SizedBox(
        width: 104,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(
              url: subject.images.medium,
              width: 104,
              height: 139,
              radius: 6,
              type: subject.type,
            ),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                children: [
                  if (collection.isNotEmpty) ...[
                    TextSpan(
                      text: collection,
                      style: titleStyle.copyWith(
                        color: _collectionColor(context, collection),
                      ),
                    ),
                    TextSpan(text: '·', style: titleStyle),
                  ],
                  TextSpan(text: title, style: titleStyle),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (matched.isNotEmpty)
              Text(
                matched.join(' / '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.ds.accent,
                ),
              ),
            if (score.isNotEmpty || clock.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (score.isNotEmpty) score,
                  if (clock.isNotEmpty) clock,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarLine extends ConsumerWidget {
  final Subject subject;
  final String time;
  final String collection;
  final List<String> highlight;

  const _CalendarLine({
    required this.subject,
    required this.time,
    this.collection = '',
    this.highlight = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = time.isNotEmpty && time != '99:99' ? time : '';
    final rating = subject.rating;
    final hideScore = SettingsStore.instance.hideScore;
    final score = !hideScore && rating != null && rating.score > 0
        ? rating.score.toStringAsFixed(1)
        : '';
    final matched = highlight.where((word) {
      final blob =
          '${subject.summary} ${subject.name} ${subject.nameCn} ${subject.displayName}';
      return blob.contains(word.replaceAll('改', '')) || blob.contains(word);
    }).toList();
    return InkWell(
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () {
        showCollectionSheet(context, subject.id).then((_) {
          ref.invalidate(progressProvider('all'));
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                clock.isEmpty ? '' : clock,
                style: context.ds.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Cover(
              url: subject.images.medium,
              width: 56,
              height: 75,
              radius: 6,
              type: subject.type,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        if (collection.isNotEmpty) ...[
                          TextSpan(
                            text: collection,
                            style: context.ds.bodyStrong.copyWith(
                              color: _collectionColor(context, collection),
                            ),
                          ),
                          TextSpan(text: '·', style: context.ds.bodyStrong),
                        ],
                        TextSpan(
                          text: subject.displayName,
                          style: context.ds.bodyStrong,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (matched.isNotEmpty)
                    Text(
                      matched.join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.ds.tiny.copyWith(
                        color: context.ds.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (score.isNotEmpty)
                    Text(
                      score,
                      style: context.ds.tiny.copyWith(color: context.ds.accent),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _collectionColor(BuildContext context, String collection) {
  if (collection.contains('在')) return context.ds.success;
  if (collection.contains('过')) return context.ds.accent;
  if (collection.contains('想')) return context.ds.star;
  if (collection.contains('搁置') || collection.contains('抛弃')) {
    return context.ds.textHint;
  }
  return context.ds.textSecondary;
}

class _CalendarNowLine extends StatelessWidget {
  final String clock;
  const _CalendarNowLine({required this.clock});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 18, height: 1, color: context.ds.accent),
          const SizedBox(height: 8),
          Icon(Icons.access_time, size: 16, color: context.ds.accent),
          const SizedBox(height: 4),
          Text(
            clock,
            style: context.ds.caption.copyWith(
              color: context.ds.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 18, height: 1, color: context.ds.accent),
        ],
      ),
    );
  }
}

Future<void> _exportWeekIcs(BuildContext context, WidgetRef ref) async {
  final days = ref.read(calendarProvider).valueOrNull;
  if (days == null || days.isEmpty) {
    showBgmToast(context, '暂无放送数据');
    return;
  }
  final times = ref.read(onAirTimeProvider).valueOrNull ?? const {};
  final now = DateTime.now();
  final items = <({int id, String title, String airdate, String clock})>[];
  for (final day in days) {
    final diff = (day.weekday - (now.weekday % 7) + 7) % 7;
    final date = now.add(Duration(days: diff));
    final stamp =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final subject in day.items) {
      final raw = times[subject.id] ?? '2000';
      final clock = raw.contains(':')
          ? raw.replaceAll(':', '')
          : (raw.length == 4 ? raw : '2000');
      items.add((
        id: subject.id,
        title: subject.displayName,
        airdate: stamp,
        clock: clock,
      ));
    }
  }
  if (items.isEmpty) {
    if (context.mounted) {
      showBgmToast(context, '没有可导出的条目');
    }
    return;
  }
  await shareWeekOnAirIcs(items);
}

/// 每日放送 (按星期 0=周日..6=周六)
final calendarProvider = FutureProvider<List<CalendarDay>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List)
      .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
      .toList();
  // 早上 9 点前先显示前一天 (原项目 PREV_DAY_HOUR)
  final now = DateTime.now();
  var start = now.weekday % 7;
  if (now.hour < 9) start = (start + 6) % 7;
  return [...days.sublist(start), ...days.sublist(0, start)];
});

/// 放送时间表: subjectId -> 'HH:MM' (bangumi-data 开源数据)
final onAirTimeProvider = FutureProvider<Map<int, String>>((ref) async {
  final client = ref.read(apiClientProvider);
  try {
    final data = await client.get(
      apiBangumiData(),
      host: 'https://bangumi-data.github.io',
    );
    final map = <int, String>{};
    for (final e in (data['items'] as List? ?? const [])) {
      final item = e as Map<String, dynamic>;
      final id = (item['subjectId'] as num?)?.toInt() ?? 0;
      if (id == 0) continue;
      final timeCN = item['timeCN'] as String? ?? '';
      final timeJP = item['timeJP'] as String? ?? '';
      map[id] = timeCN.isNotEmpty ? timeCN : timeJP;
    }
    return map;
  } catch (_) {
    // 放送时间表获取失败仅不显示时间
    return const {};
  }
});

({List<String> adapts, List<String> tags, List<String> studios})
calendarFilterOptions(List<CalendarDay> days) {
  const adaptKeys = ['原创', '漫画改', '小说改', '游戏改', '其他改'];
  const studioHints = [
    '动画',
    '制作',
    'studio',
    'MAPPA',
    '京都',
    'ufotable',
    'Clover',
    'Production',
    'Bones',
    'WIT',
    'A-1',
    'SHAFT',
    'TRIGGER',
    'P.A.',
    'J.C.',
    'Gainax',
    'SUNRISE',
    'Sunrise',
    '东映',
    'TMS',
    'OLM',
    'Toei',
  ];
  final adaptCount = <String, int>{};
  final tagCount = <String, int>{};
  final studioCount = <String, int>{};
  for (final day in days) {
    for (final subject in day.items) {
      for (final tag in subject.tags) {
        final name = tag.name.trim();
        if (name.isEmpty) continue;
        if (adaptKeys.contains(name)) {
          adaptCount[name] = (adaptCount[name] ?? 0) + 1;
        } else if (studioHints.any(name.contains)) {
          studioCount[name] = (studioCount[name] ?? 0) + 1;
        } else {
          tagCount[name] = (tagCount[name] ?? 0) + 1;
        }
      }
    }
  }
  List<String> ranked(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ['全部', for (final e in entries.take(16)) '${e.key} (${e.value})'];
  }

  return (
    adapts: ranked(adaptCount),
    tags: ranked(tagCount),
    studios: ranked(studioCount),
  );
}
