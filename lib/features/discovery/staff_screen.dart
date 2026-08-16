import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import 'widgets/season_filter.dart';
import '../../shared/widgets/bgm_button.dart';

/// 原版 HeaderV2Popover DATA: 浏览器查看 + 网页版查看
const kStaffMoreItems = <(String, String)>[
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
];

/// 新番 (按季度放送列表)
///
/// 原项目抓取用户 "lilyurey" 的收藏目录, 这里使用 bgm.tv 主站季度新番
/// 列表等价实现: /anime/tag/TV/airtime/{年}-{月}?sort=rank (原
/// /anime/browser/airtime 路径被 CDN 拦截, 标签页提供相同数据)。
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late int _year = DateTime.now().year;
  late int? _month = DateTime.now().month;

  String get _basePath =>
      htmlSeasonBrowser(year: _year, month: _month, sort: 'rank');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '新番',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: kStaffMoreItems,
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl('$kHost/user/lilyurey/index');
              } else if (value == 'spa') {
                openExternalUrl(htmlSpa('Staff'));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$_year 年 ${_month ?? 1} 月新番',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          SeasonFilter(
            year: _year,
            month: _month,
            sort: 'rank',
            onYear: (v) => setState(() => _year = v),
            onMonth: (v) => setState(() => _month = v),
            onSort: (_) {},
            sortOptions: const [('rank', '排名')],
          ),
          Expanded(child: BrowserGrid(basePath: _basePath)),
        ],
      ),
    );
  }
}
