import '../webview/note_screen.dart';

String tinygrailAdvanceNotePath() {
  return extraNotePath(
    title: '高级功能',
    message: const [
      '本栏目基于角色股息，仅供参考。',
      '普通用户每项 4 小时只能刷新一次。',
      '高级用户也有 1 分钟限制，避免误刷新。',
      '高级用户为付过费用户，人工维护。',
    ],
  );
}

String tinygrailAdvanceAskNotePath() {
  return extraNotePath(
    title: '买入推荐',
    message: const [
      '当前计算方式：从活跃列表里面查找',
      '第一卖单股数大于 10，且流动股息或圣殿股息大于 4',
      '用较大的股息除以第一卖单价再乘 10 得到分数',
    ],
  );
}

String tinygrailAdvanceBidNotePath() {
  return extraNotePath(
    title: '卖出推荐',
    message: const [
      '当前计算方式',
      '从持仓列表里面查找',
      '第一买单股数 > 0',
      '第一买单价 / Math.min(500, rank) 时的实际股息 = 分数',
    ],
  );
}

String tinygrailAdvanceAuctionNotePath() {
  return extraNotePath(
    title: '拍卖推荐',
    message: const [
      '当前计算方式',
      '从英灵殿里面查找前 2000 条',
      '可竞拍数量 > 80',
      '实时股息 / 竞拍底价 * 100 = 分数',
    ],
  );
}

String tinygrailAdvanceAuction2NotePath() {
  return extraNotePath(
    title: '拍卖推荐 B',
    message: const [
      '当前计算方式',
      '从英灵殿里面查找前 2000 条',
      '数量 > 80',
      '若当前 rank > 500 按 500 时的实际股息 / 竞拍底价 * 100 = 分数',
    ],
  );
}

String tinygrailAdvanceStateNotePath() {
  return extraNotePath(
    title: '低价股',
    message: const ['当前计算方式', '在英灵殿里面查找当前价 <= 16 的角色, 获取卖一价'],
  );
}

String tinygrailAdvanceSacrificeNotePath() {
  return extraNotePath(
    title: '献祭推荐',
    message: const ['当前计算方式', '从持仓列表里面查找', '圣殿股息 - 流动股息 = 分数'],
  );
}

String tinygrailTreeNotePath() {
  return extraNotePath(
    title: '小圣杯助手',
    message: const [
      '1. 单击方格展开功能菜单, 长按隐藏方格',
      '2. 本功能处于实验性阶段, 不保证能正常渲染, 不正常请尝试刷新或者在讨论组等联系作者',
      '3. 计算的数据只供参考, 不排除会出现不准确丢失的情况',
      '4. 因角色数量可能导致流量变大, 页面当有缓存数据不会自动刷新, 请点击旁边的按钮刷新',
      '5. 部分数据可能毫无意义, 只是顺便调出来, 还请自己把握(bgm38)',
    ],
  );
}

const kTinygrailItemNoteNames = ['混沌魔方', '虚空道标', '星光碎片', '闪光结晶', '鲤鱼之眼'];

String tinygrailItemNotePath(String name) {
  return extraNotePath(
    title: name,
    message: switch (name) {
      '混沌魔方' => const ['随机抢其他玩家 20-200 股。', '消耗 10 固定资产和 1 魔方，每日限 3 次。'],
      '虚空道标' => const ['指定抢某角色 10-100 股。', '消耗 100 固定资产和 1 道标，每日限 5 次。'],
      '星光碎片' => const ['消耗 A 角色活股，补充 B 角色固定资产。', '消耗 1 碎片加对应活股。'],
      '闪光结晶' => const ['对目标角色星之力造成伤害。', '消耗 100 固定资产和 1 结晶。'],
      '鲤鱼之眼' => const ['把幻想乡的股转到英灵殿。', '消耗 100 固定资产和 1 鲤鱼之眼，每日限 1 次。'],
      _ => const [],
    },
    url: name == '闪光结晶'
        ? 'https://bgm.tv/group/topic/388838#post_2504306'
        : 'https://bgm.tv/group/topic/388838#post_2504302',

    ai: true,
  );
}
