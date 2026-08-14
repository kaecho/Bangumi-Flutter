import '../webview/note_screen.dart';

/// 原项目 TEXT_UPDATE_TYPERANK
const kTypeRankSnapshot = '2026-04-12';

String typeRankNotePath() {
  return extraNotePath(
    title: '分类排行',
    message: const [
      '此功能目前仅存在于客户端',
      '简单说这个标签分类排行榜生成过程：',
      '1. 数据来源：收集全站所有带排名的条目（动画/书/游戏/音乐等）',
      '2. 时间快照：在某个特定时间点，对这些条目进行"拍照"记录',
      '3. 标签筛选：找出这些条目使用的热门标签',
      '4. 精选TOP100：只选取排名最高的前100个条目',
      '5. 最终榜单：统计这些精选条目的所有标签，生成排行榜',
      '6. 补充：因为全站的标签均为用户编辑导向的，故会出现不符合预期的情况，仅供参考',
      '通常一年更新一次，最后一次快照时间为：$kTypeRankSnapshot',
    ],
  );
}

String wordCloudNotePath() {
  return extraNotePath(
    title: '词云',
    message: const [
      '数据是从官方用户收藏 API 批量获取的。',
      '因参与计算的数据会因收藏条目的递增呈爆炸式增长，所以目前每次批量获取只取了想看前 2 页、在看前 3 页、看过前 5 页，每页 100 个。',
      '瞬间过多的计算可能会导致客户端崩溃闪退，若出现请适当使用筛选减少计算的范围，以得到你需要的结果。',
    ],
  );
}
