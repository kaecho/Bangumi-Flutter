import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

/// 每日放送
///
/// 数据来源:
/// - GET /calendar — 一周 7 天的条目分组
/// - bangumi-data 放送时间表 (https://bangumi-data.github.io/bangumi-data/data.json,
///   与原项目 protobuf 版 bangumi-data 同源) — 每条目的放送时间
/// 放送时间表获取失败时仅不显示时间, 不影响条目列表。
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(calendarProvider);
    return Scaffold(
      appBar: const BgmAppBar(title: '每日放送', showBackButton: true),
      body: days.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(calendarProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(calendarProvider);
            ref.invalidate(onAirTimeProvider);
            await ref.read(calendarProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length,
            itemBuilder: (context, index) =>
                _DaySection(day: list[index]),
          ),
        ),
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  final CalendarDay day;

  const _DaySection({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = day.items;
    // 按放送时间排序 (未知时间排最后)
    final sorted = [...items]
      ..sort((a, b) => _timeOf(ref, a.id).compareTo(_timeOf(ref, b.id)));
    // 同一时间只保留第一个显示
    final shownTimes = <String>{};

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
              Text(
                _sectionDate(day.weekday),
                style: context.ds.caption,
              ),
            ],
          ),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              '暂无放送',
              style: context.ds.caption,
            ),
          )
        else
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final subject = sorted[index];
                final time = _timeOf(ref, subject.id);
                final showTime = time.isNotEmpty && shownTimes.add(time);
                return _CalendarCard(
                  subject: subject,
                  time: showTime ? time : '',
                );
              },
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

class _CalendarCard extends StatelessWidget {
  final Subject subject;
  final String time;

  const _CalendarCard({required this.subject, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = subject.rating;
    final info = rating != null && rating.score > 0
        ? '${rating.score.toStringAsFixed(1)}分'
        : (subject.eps > 0 ? '全 ${subject.eps} 话' : '');

    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Cover(
                  url: subject.images.medium,
                  width: 104,
                  height: 139,
                  radius: 6,
                ),
                if (time.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subject.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.25, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 2),
            if (info.isNotEmpty)
              Text(
                info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 每日放送 (按星期 0=周日..6=周六)
final calendarProvider = FutureProvider<List<CalendarDay>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List)
      .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
      .toList();
  // 排序: 从今天开始
  final today = DateTime.now().weekday % 7;
  return [...days.sublist(today), ...days.sublist(0, today)];
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
