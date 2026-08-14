import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';

/// 年鉴年份 (award 页年份菜单复用)
const kYearbookYears = [
  2024,
  2023,
  2022,
  2021,
  2020,
  2019,
  2018,
  2017,
  2016,
  2015,
  2014,
  2013,
  2012,
  2011,
  2010,
];

/// 年鉴 (对齐原项目: 近年横幅 + 图块 + 更早年份格)
class YearbookScreen extends StatelessWidget {
  const YearbookScreen({super.key});

  static const _bannerYears = [2024, 2023, 2022];
  static const _tileYears = [2021, 2020, 2019, 2018];
  static const _gridYears = [2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: BgmAppBar(title: 'Bangumi年鉴', showBackButton: true),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          for (final year in _bannerYears)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _YearCard(
                year: year,
                height: 88,
                titleSize: 28,
                subtitle: '年度动画大赏',
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final year in _tileYears)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 34) / 2,
                  child: _YearCard(
                    year: year,
                    height: 76,
                    titleSize: 22,
                    subtitle: '年鉴',
                    color: theme.colorScheme.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.2,
            children: [
              for (final year in _gridYears)
                _YearCard(
                  year: year,
                  height: 56,
                  titleSize: 16,
                  subtitle: '',
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  final int year;
  final double height;
  final double titleSize;
  final String subtitle;
  final Color color;

  const _YearCard({
    required this.year,
    required this.height,
    required this.titleSize,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/award/$year'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$year',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
