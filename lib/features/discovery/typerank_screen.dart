import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/browser_grid.dart';
import 'widgets/season_filter.dart';

/// 分类排行 (按标签筛选条目)
///
/// 原项目使用本地 id 列表 + v0 条目 API, 这里使用 bgm.tv 主站
/// 标签条目页等价实现: /{type}/tag/{tag}?sort=rank&page=..
class TypeRankScreen extends StatefulWidget {
  const TypeRankScreen({super.key});

  @override
  State<TypeRankScreen> createState() => _TypeRankScreenState();
}

class _TypeRankScreenState extends State<TypeRankScreen> {
  String _type = 'anime';
  String _tag = 'TV';

  static const _tags = ['TV', '剧场版', 'OVA', 'WEB', '治愈', '恋爱', '搞笑', '原创', '冒险', '科幻'];

  String get _basePath => htmlTagSubjects(_type, _tag);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '分类排行', showBackButton: true),
      body: Column(
        children: [
          TypeTabs(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
            options: const [
              ('anime', '动画'),
              ('book', '书籍'),
              ('game', '游戏'),
            ],
          ),
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
          Expanded(
            child: BrowserGrid(basePath: _basePath),
          ),
        ],
      ),
    );
  }
}
