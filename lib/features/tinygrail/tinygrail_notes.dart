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
