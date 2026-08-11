import 'package:flutter/material.dart';

import '../../../shared/widgets/score.dart';

/// 年份/季度/排序 筛选条 (找条目 / 新番 / 索引 共用)
class SeasonFilter extends StatelessWidget {
  final int year;
  final int? month; // null = 全年
  final String sort;
  final ValueChanged<int> onYear;
  final ValueChanged<int?> onMonth;
  final ValueChanged<String> onSort;
  final bool showMonth;
  final List<(String, String)> sortOptions;

  const SeasonFilter({
    super.key,
    required this.year,
    required this.month,
    required this.sort,
    required this.onYear,
    required this.onMonth,
    required this.onSort,
    this.showMonth = true,
    this.sortOptions = const [
      ('rank', '排名'),
      ('date', '日期'),
      ('trends', '热度'),
      ('collects', '收藏'),
    ],
  });

  static const kYears = [2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Dropdown<int>(
            value: year,
            items: [for (final y in kYears) (y, '$y 年')],
            onChanged: onYear,
          ),
          if (showMonth) ...[
            const SizedBox(width: 8),
            _Dropdown<int?>(
              value: month,
              items: [
                (null, '全年'),
                for (var m = 1; m <= 12; m++) (m, '$m 月'),
              ],
              onChanged: onMonth,
            ),
          ],
          const SizedBox(width: 8),
          _Dropdown<String>(
            value: sort,
            items: sortOptions,
            onChanged: onSort,
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(value: v, child: Text(label)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// 通用 Tab 筛选条 (动画/书籍/三次元/游戏)
class TypeTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> options;

  const TypeTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const [
      ('anime', '动画'),
      ('book', '书籍'),
      ('real', '三次元'),
      ('game', '游戏'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (v, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tag(
                text: label,
                active: value == v,
                onTap: () => onChanged(v),
              ),
            ),
        ],
      ),
    );
  }
}
