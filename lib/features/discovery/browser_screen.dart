import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import 'widgets/season_filter.dart';

/// 索引 (条目浏览器)
///
/// 原项目抓取 /{type}/browser/airtime/{ym} (该路径现被 CDN 拦截),
/// 这里用等价数据: 动画为标签+放送季页, 其余类型为普通浏览页。
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  String _type = 'anime';
  int _year = DateTime.now().year;
  int? _month;
  String _sort = 'date';

  String get _basePath {
    if (_type == 'anime') {
      return htmlSeasonBrowser(year: _year, month: _month, sort: _sort);
    }
    return htmlRankBrowser(_type, sort: _sort == 'date' ? 'rank' : _sort);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '索引', showBackButton: true),
      body: Column(
        children: [
          TypeTabs(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          if (_type == 'anime')
            SeasonFilter(
              year: _year,
              month: _month,
              sort: _sort,
              onYear: (v) => setState(() => _year = v),
              onMonth: (v) => setState(() => _month = v),
              onSort: (v) => setState(() => _sort = v),
            ),
          Expanded(
            child: BrowserGrid(basePath: _basePath),
          ),
        ],
      ),
    );
  }
}
