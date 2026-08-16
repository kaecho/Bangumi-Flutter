import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/browser_grid.dart';
import 'widgets/season_filter.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/filter_switch.dart';

/// 找条目 (找番剧)
///
/// 原项目使用本地打包数据集 + 私有 KV 快照 (不可移植), 这里用 bgm.tv
/// 主站条目浏览器等价实现: 按 类型/年份/季度/排序 过滤动画列表。
/// 顶栏 Extra 对齐原版: 切布局 + 回顶, 不是地球图标。
class AnimeScreen extends ConsumerStatefulWidget {
  const AnimeScreen({super.key});

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen> {
  final _scroll = ScrollController();
  String _tag = 'TV';
  int _year = DateTime.now().year;
  int? _month = DateTime.now().month;
  String _sort = 'rank';

  static const _tags = ['TV', '剧场版', 'OVA', 'WEB', '其他'];

  String get _basePath =>
      htmlSeasonBrowser(tag: _tag, year: _year, month: _month, sort: _sort);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '找番剧',
        showBackButton: true,
        actions: [
          BgmDiscoveryExtra(
            isList: store.discoveryList,
            onToggleLayout: () => store.setDiscoveryList(!store.discoveryList),
            onScrollToTop: () => scrollBgmToTop(_scroll),
          ),
        ],
      ),
      body: Column(
        children: [
          const DiscoveryFilterSwitch(name: '番剧'),

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
          Expanded(
            child: BrowserGrid(
              basePath: _basePath,
              isList: store.discoveryList,
              controller: _scroll,
            ),
          ),
        ],
      ),
    );
  }
}
