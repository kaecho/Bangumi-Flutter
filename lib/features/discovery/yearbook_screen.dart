import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';
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

const kYearbookBannerYear = 2022;
const kYearbookBlockYears = [2021, 2020, 2019, 2018];
const kYearbookGridYears = [2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010];

const _kBlockColors = {
  2021: Color(0xFFEBF3EC),
  2020: Color(0xFFECF3EC),
  2019: Color(0xFF363F45),
  2018: Color(0xFF000000),
};

/// 年鉴 (对齐原项目: 2022 横幅 + 2018-2021 图块 + 2010-2017 两列方格)
class YearbookScreen extends StatelessWidget {
  const YearbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final width = MediaQuery.sizeOf(context).width - 32;
    final bannerHeight = (width * 0.4).floorToDouble();
    return Scaffold(
      appBar: BgmAppBar(title: 'Bangumi年鉴', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _YearImageCard(
            year: kYearbookBannerYear,
            width: width,
            height: bannerHeight,
            background: Colors.white,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          for (final year in kYearbookBlockYears) ...[
            _YearImageCard(
              year: year,
              width: width,
              height: bannerHeight,
              background: _kBlockColors[year] ?? ds.surfaceCard,
              padding: year == 2019
                  ? const EdgeInsets.only(left: 18)
                  : year == 2018
                  ? const EdgeInsets.only(left: 10)
                  : EdgeInsets.zero,
              fit: year == 2018 ? BoxFit.cover : BoxFit.contain,
            ),
            const SizedBox(height: 12),
          ],
          _YearGrid(years: kYearbookGridYears),
        ],
      ),
    );
  }
}

class _YearImageCard extends StatelessWidget {
  final int year;
  final double width;
  final double height;
  final Color background;
  final EdgeInsets padding;
  final BoxFit fit;

  const _YearImageCard({
    required this.year,
    required this.width,
    required this.height,
    required this.background,
    this.padding = EdgeInsets.zero,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/award/$year'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: padding,
            child: Image.asset(
              'assets/images/static/$year.png',
              width: width,
              height: height,
              fit: fit,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearGrid extends StatelessWidget {
  final List<int> years;

  const _YearGrid({required this.years});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tile = ((MediaQuery.sizeOf(context).width - 32 - 16) / 2)
        .floorToDouble();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final year in years)
          GestureDetector(
            onTap: () => context.push('/award/$year'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: dark ? ds.surfaceCard : ds.textPrimary,
                child: SizedBox(
                  width: tile,
                  height: tile,
                  child: Center(
                    child: Text(
                      '$year',
                      style: ds.title.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
