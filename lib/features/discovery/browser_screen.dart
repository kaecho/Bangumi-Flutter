import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/browser_grid.dart';

/// 索引类型 (原项目 SUBJECT_TYPE)
const kBrowserTypes = <(String, String)>[
  ('anime', '动画'),
  ('book', '书籍'),
  ('music', '音乐'),
  ('game', '游戏'),
  ('real', '三次元'),
];

/// 索引排序 (原项目 BROWSER_SORT)
const kBrowserSorts = <(String, String)>[
  ('', '默认'),
  ('rank', '排名'),
  ('date', '时间'),
];

/// 索引年 (原项目 DATA_BROWSER_AIRTIME, 当年到 1949)
List<int> browserYears([int? now]) {
  final end = now ?? DateTime.now().year;
  return [for (var y = end; y >= 1949; y--) y];
}

/// 原版 HeaderV2Popover: 浏览器查看 + 网页版查看 + toolBar
List<(String, String)> browserMoreItems({
  required bool fixed,
  required bool list,
  required bool collected,
}) => [
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
  ('toolbar', '工具栏〔${fixed ? '锁定' : '浮动'}〕'),
  ('layout', '布　局〔${list ? '列表' : '网格'}〕'),
  ('favor', '收　藏〔${collected ? '显示' : '不显示'}〕'),
];

/// 索引 (原项目 discovery/browser)
///
/// 类型 / 年 / 月走工具栏 Popover, 对齐原版 ToolBar;
/// 布局 / 收藏 / 浏览器查看走顶栏横点。
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final _now = DateTime.now();
  late String _type = 'anime';
  late int _year = _now.year;
  late int? _month = _now.month;
  String _sort = 'date';
  bool _list = true;
  bool _collected = true;
  bool _fixed = false;

  String get _airtime => _month == null ? '$_year' : '$_year-$_month';

  String get _path => htmlBrowser(_type, airtime: _airtime, sort: _sort);

  void _shiftMonth(int delta) {
    if (_month == null) {
      setState(() => _year += delta);
      return;
    }
    var year = _year;
    var month = _month! + delta;
    if (month < 1) {
      year -= 1;
      month = 12;
    } else if (month > 12) {
      year += 1;
      month = 1;
    }
    setState(() {
      _year = year;
      _month = month;
    });
  }

  Widget _toolBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          BgmSelect<String>(
            tooltip: '类型',
            value: _type,
            items: kBrowserTypes,
            onChanged: (v) => setState(() => _type = v),
          ),
          BgmHeaderAction(
            tooltip: '前一月',
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () => _shiftMonth(-1),
          ),
          BgmSelect<int>(
            tooltip: '年',
            value: _year,
            items: [
              for (final y in browserYears(
                _year > _now.year ? _year : _now.year,
              ))
                (y, '$y'),
            ],
            onChanged: (v) => setState(() => _year = v),
          ),
          BgmSelect<int?>(
            tooltip: '月',
            value: _month,
            items: [(null, '全部'), for (var m = 1; m <= 12; m++) (m, '$m月')],
            onChanged: (v) => setState(() => _month = v),
          ),
          BgmHeaderAction(
            tooltip: '后一月',
            icon: const Icon(Icons.arrow_forward, size: 18),
            onPressed: () => _shiftMonth(1),
          ),
          BgmSelect<String>(
            tooltip: '排序',
            value: _sort,
            items: kBrowserSorts,
            onChanged: (v) => setState(() => _sort = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolBar = _toolBar();
    final grid = BrowserGrid(
      basePath: _path,
      isList: _list,
      collected: _collected,
      header: _fixed ? null : toolBar,
    );
    return Scaffold(
      appBar: BgmAppBar(
        title: '索引',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: browserMoreItems(
              fixed: _fixed,
              list: _list,
              collected: _collected,
            ),
            onSelected: (value) {
              switch (value) {
                case 'browser':
                  openExternalUrl('$kHost$_path');
                case 'spa':
                  openExternalUrl(htmlSpa('Browser'));
                case 'toolbar':
                  setState(() => _fixed = !_fixed);
                case 'layout':
                  setState(() => _list = !_list);
                case 'favor':
                  setState(() => _collected = !_collected);
              }
            },
          ),
        ],
      ),
      body: _fixed
          ? Column(
              children: [
                toolBar,
                Expanded(child: grid),
              ],
            )
          : grid,
    );
  }
}
