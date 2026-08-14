import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/browser_grid.dart';
import 'widgets/season_filter.dart';

/// 找条目 (找番剧)
///
/// 原项目使用本地打包数据集 + 私有 KV 快照 (不可移植), 这里用 bgm.tv
/// 主站条目浏览器等价实现: 按 类型/年份/季度/排序 过滤动画列表。
class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  String _tag = 'TV';
  int _year = DateTime.now().year;
  int? _month = DateTime.now().month;
  String _sort = 'rank';

  static const _tags = ['TV', '剧场版', 'OVA', 'WEB', '其他'];

  String get _basePath =>
      htmlSeasonBrowser(tag: _tag, year: _year, month: _month, sort: _sort);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '找番剧',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl('$kHost$_basePath'),
          ),
        ],
      ),

      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final tag in _tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tag(
                      text: tag,
                      active: _tag == tag,
                      onTap: () => setState(() => _tag = tag),
                    ),
                  ),
              ],
            ),
          ),
          SeasonFilter(
            year: _year,
            month: _month,
            sort: _sort,
            onYear: (v) => setState(() => _year = v),
            onMonth: (v) => setState(() => _month = v),
            onSort: (v) => setState(() => _sort = v),
          ),
          Expanded(child: BrowserGrid(basePath: _basePath)),
        ],
      ),
    );
  }
}
