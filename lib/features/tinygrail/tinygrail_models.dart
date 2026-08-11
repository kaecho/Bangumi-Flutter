/// 小圣杯数据模型 (移植自原项目 stores/tinygrail + screens/tinygrail)
library;

/// 角色 (列表 / 详情通用; 字段缺失时默认 0 / 空)
class TinygrailChara {
  final int id;
  final int monoId;
  final String name;
  final String icon;
  final int level;
  final int current;
  final int total;
  final int users;
  final int state;
  final int change;
  final double fluctuation;
  final int asks;
  final int bids;
  final int bonus;
  final String end;
  final int icoId;
  final String lastDeal;
  final String lastOrder;
  final int marketValue;
  final int price;
  final int rank;
  final double rate;
  final int starForces;
  final int stars;
  final int sacrifices;
  final String listedDate;
  final int crown;
  final int subjectId;
  final String subjectName;
  final int st;
  final int userAmount;
  final int userTotal;
  final int type;
  final int amount;

  const TinygrailChara({
    this.id = 0,
    this.monoId = 0,
    this.name = '',
    this.icon = '',
    this.level = 0,
    this.current = 0,
    this.total = 0,
    this.users = 0,
    this.state = 0,
    this.change = 0,
    this.fluctuation = 0,
    this.asks = 0,
    this.bids = 0,
    this.bonus = 0,
    this.end = '',
    this.icoId = 0,
    this.lastDeal = '',
    this.lastOrder = '',
    this.marketValue = 0,
    this.price = 0,
    this.rank = 0,
    this.rate = 0,
    this.starForces = 0,
    this.stars = 0,
    this.sacrifices = 0,
    this.listedDate = '',
    this.crown = 0,
    this.subjectId = 0,
    this.subjectName = '',
    this.st = 0,
    this.userAmount = 0,
    this.userTotal = 0,
    this.type = 0,
    this.amount = 0,
  });

  factory TinygrailChara.fromJson(Map<String, dynamic> json) {
    final id = (json['CharacterId'] ?? json['Id'] ?? 0) as num;
    final fluctuation = (json['Fluctuation'] ?? 0) as num;
    final monoId = (json['CharacterId'] ?? json['Id'] ?? json['MonoId'] ?? 0) as num;
    return TinygrailChara(
      id: id.toInt(),
      monoId: monoId.toInt(),
      name: json['Name'] as String? ?? '',
      icon: json['Icon'] as String? ?? '',
      level: (json['Level'] as num?)?.toInt() ?? 0,
      current: (json['Current'] as num?)?.toInt() ?? 0,
      total: (json['Total'] as num?)?.toInt() ?? 0,
      users: (json['Users'] as num?)?.toInt() ?? 0,
      state: (json['State'] as num?)?.toInt() ?? 0,
      change: (json['Change'] as num?)?.toInt() ?? 0,
      // 列表接口涨跌幅已是百分比, 详情接口为小数
      fluctuation: (fluctuation >= -1 && fluctuation <= 1 && json['Fluctuation'] != null
              ? fluctuation * 100
              : fluctuation)
          .toDouble(),
      asks: (json['Asks'] as num?)?.toInt() ?? 0,
      bids: (json['Bids'] as num?)?.toInt() ?? 0,
      bonus: (json['Bonus'] as num?)?.toInt() ?? 0,
      end: json['End'] as String? ?? '',
      icoId: (json['IcoId'] as num?)?.toInt() ?? 0,
      lastDeal: json['LastDeal'] as String? ?? '',
      lastOrder: json['LastOrder'] as String? ?? '',
      marketValue: (json['MarketValue'] as num?)?.toInt() ?? 0,
      price: (json['Price'] as num?)?.toInt() ?? 0,
      rank: (json['Rank'] as num?)?.toInt() ?? 0,
      rate: (json['Rate'] as num?)?.toDouble() ?? 0,
      starForces: (json['StarForces'] as num?)?.toInt() ?? 0,
      stars: (json['Stars'] as num?)?.toInt() ?? 0,
      sacrifices: ((json['Sacrifices'] ?? json['Sa'] ?? 0) as num).toInt(),
      listedDate: json['ListedDate'] as String? ?? '',
      crown: (json['Crown'] as num?)?.toInt() ?? 0,
      subjectId: (json['SubjectId'] as num?)?.toInt() ?? 0,
      subjectName: json['SubjectName'] as String? ?? '',
      st: (json['St'] as num?)?.toInt() ?? 0,
      userAmount: (json['UserAmount'] as num?)?.toInt() ?? 0,
      userTotal: (json['UserTotal'] as num?)?.toInt() ?? 0,
      type: (json['Type'] as num?)?.toInt() ?? 0,
      amount: (json['Amount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 用户资产
class TinygrailUser {
  final String hash;
  final String nickname;
  final String avatar;
  final int balance;
  final int principal;
  final int amount;
  final int total;
  final int lastIndex;

  const TinygrailUser({
    this.hash = '',
    this.nickname = '',
    this.avatar = '',
    this.balance = 0,
    this.principal = 0,
    this.amount = 0,
    this.total = 0,
    this.lastIndex = 0,
  });

  factory TinygrailUser.fromJson(Map<String, dynamic> json) => TinygrailUser(
        hash: json['Hash'] as String? ?? '',
        nickname: json['Nickname'] as String? ?? '',
        avatar: json['Avatar'] as String? ?? '',
        balance: (json['Balance'] as num?)?.toInt() ?? 0,
        principal: (json['Principal'] as num?)?.toInt() ?? 0,
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        total: (json['Total'] as num?)?.toInt() ?? 0,
        lastIndex: (json['LastIndex'] as num?)?.toInt() ?? 0,
      );
}

/// 番市首富 / 富豪榜条目
class TinygrailRich {
  final String avatar;
  final String nickname;
  final String userId;
  final int assets;
  final int total;
  final int principal;
  final int lastActiveDate;
  final int lastIndex;
  final int state;
  final int rank;

  const TinygrailRich({
    this.avatar = '',
    this.nickname = '',
    this.userId = '',
    this.assets = 0,
    this.total = 0,
    this.principal = 0,
    this.lastActiveDate = 0,
    this.lastIndex = 0,
    this.state = 0,
    this.rank = 0,
  });

  factory TinygrailRich.fromJson(Map<String, dynamic> json, {int rank = 0}) => TinygrailRich(
        avatar: json['Avatar'] as String? ?? '',
        nickname: json['Nickname'] as String? ?? '',
        userId: json['Name'] as String? ?? '',
        assets: (json['Assets'] as num?)?.toInt() ?? 0,
        total: ((json['TotalBalance'] ?? json['Total'] ?? 0) as num).toInt(),
        principal: (json['Principal'] as num?)?.toInt() ?? 0,
        lastActiveDate: (json['LastActiveDate'] as num?)?.toInt() ?? 0,
        lastIndex: (json['LastIndex'] as num?)?.toInt() ?? 0,
        state: (json['State'] as num?)?.toInt() ?? 0,
        rank: rank,
      );
}

/// 深度图条目
class TinygrailDepthItem {
  final double price;
  final int amount;
  final int type;

  const TinygrailDepthItem({this.price = 0, this.amount = 0, this.type = 0});

  factory TinygrailDepthItem.fromJson(Map<String, dynamic> json) => TinygrailDepthItem(
        price: (json['Price'] as num?)?.toDouble() ?? 0,
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        type: (json['Type'] as num?)?.toInt() ?? 0,
      );
}

/// 深度图
class TinygrailDepth {
  final List<TinygrailDepthItem> bids;
  final List<TinygrailDepthItem> asks;

  const TinygrailDepth({this.bids = const [], this.asks = const []});

  factory TinygrailDepth.fromJson(Map<String, dynamic> json) => TinygrailDepth(
        bids: (json['Bids'] as List? ?? [])
            .map((e) => TinygrailDepthItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        asks: (json['Asks'] as List? ?? [])
            .map((e) => TinygrailDepthItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// K 线条目
class TinygrailKline {
  final String time;
  final int begin;
  final int end;
  final int low;
  final int high;
  final int amount;
  final int price;

  const TinygrailKline({
    this.time = '',
    this.begin = 0,
    this.end = 0,
    this.low = 0,
    this.high = 0,
    this.amount = 0,
    this.price = 0,
  });

  factory TinygrailKline.fromJson(Map<String, dynamic> json) => TinygrailKline(
        time: json['Time'] as String? ?? '',
        begin: (json['Begin'] as num?)?.toInt() ?? 0,
        end: (json['End'] as num?)?.toInt() ?? 0,
        low: (json['Low'] as num?)?.toInt() ?? 0,
        high: (json['High'] as num?)?.toInt() ?? 0,
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        price: (json['Price'] as num?)?.toInt() ?? 0,
      );
}

/// 用户挂单 / 交易记录条目
class TinygrailLog {
  final int id;
  final int characterId;
  final int amount;
  final int price;
  final int type;
  final String time;

  const TinygrailLog({
    this.id = 0,
    this.characterId = 0,
    this.amount = 0,
    this.price = 0,
    this.type = 0,
    this.time = '',
  });

  factory TinygrailLog.fromJson(Map<String, dynamic> json) => TinygrailLog(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        characterId: (json['CharacterId'] as num?)?.toInt() ?? 0,
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        price: (json['Price'] as num?)?.toInt() ?? 0,
        type: (json['Type'] as num?)?.toInt() ?? 0,
        time: (json['Begin'] ?? json['TradeTime'] ?? json['Time'] ?? '') as String? ?? '',
      );
}

/// 资金日志条目
class TinygrailBalance {
  final int id;
  final int balance;
  final int change;
  final String time;
  final int charaId;
  final String desc;

  const TinygrailBalance({
    this.id = 0,
    this.balance = 0,
    this.change = 0,
    this.time = '',
    this.charaId = 0,
    this.desc = '',
  });

  factory TinygrailBalance.fromJson(Map<String, dynamic> json) => TinygrailBalance(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        balance: (json['Balance'] as num?)?.toInt() ?? 0,
        change: (json['Change'] as num?)?.toInt() ?? 0,
        time: json['LogTime'] as String? ?? '',
        charaId: (json['RelatedId'] as num?)?.toInt() ?? 0,
        desc: json['Description'] as String? ?? '',
      );
}

/// 我的拍卖条目
class TinygrailAuctionItem {
  final int id;
  final int monoId;
  final String name;
  final String icon;
  final int marketValue;
  final int total;
  final double rate;
  final int amount;
  final int price;
  final int state;
  final String lastOrder;
  /// 当前拍卖状态: 人数 / 股数
  final int auctionState;
  final int auctionType;

  const TinygrailAuctionItem({
    this.id = 0,
    this.monoId = 0,
    this.name = '',
    this.icon = '',
    this.marketValue = 0,
    this.total = 0,
    this.rate = 0,
    this.amount = 0,
    this.price = 0,
    this.state = 0,
    this.lastOrder = '',
    this.auctionState = 0,
    this.auctionType = 0,
  });

  factory TinygrailAuctionItem.fromJson(Map<String, dynamic> json) {
    final auction = json['Auction'] as Map<String, dynamic>?;
    return TinygrailAuctionItem(
      id: (json['Id'] as num?)?.toInt() ?? 0,
      monoId: (json['CharacterId'] as num?)?.toInt() ?? 0,
      name: json['Name'] as String? ?? '',
      icon: json['Icon'] as String? ?? '',
      marketValue: (json['MarketValue'] as num?)?.toInt() ?? 0,
      total: (json['Total'] as num?)?.toInt() ?? 0,
      rate: (json['Rate'] as num?)?.toDouble() ?? 0,
      amount: (json['Amount'] as num?)?.toInt() ?? 0,
      price: (json['Price'] as num?)?.toInt() ?? 0,
      state: (json['State'] as num?)?.toInt() ?? 0,
      lastOrder: json['Bid'] as String? ?? json['LastOrder'] as String? ?? '',
      auctionState: (auction?['State'] as num?)?.toInt() ?? 0,
      auctionType: (auction?['Type'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ICO 参与者
class TinygrailInitial {
  final int id;
  final String avatar;
  final String userId;
  final int state;
  final String nickName;
  final String name;
  final int amount;
  final int lastIndex;
  final String begin;
  final String end;

  const TinygrailInitial({
    this.id = 0,
    this.avatar = '',
    this.userId = '',
    this.state = 0,
    this.nickName = '',
    this.name = '',
    this.amount = 0,
    this.lastIndex = 0,
    this.begin = '',
    this.end = '',
  });

  factory TinygrailInitial.fromJson(Map<String, dynamic> json) => TinygrailInitial(
        id: (json['InitialId'] as num?)?.toInt() ?? 0,
        avatar: json['Avatar'] as String? ?? '',
        userId: json['UserId'] as String? ?? '',
        state: (json['State'] as num?)?.toInt() ?? 0,
        nickName: json['NickName'] as String? ?? '',
        name: json['Name'] as String? ?? '',
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        lastIndex: (json['LastIndex'] as num?)?.toInt() ?? 0,
        begin: json['Begin'] as String? ?? '',
        end: json['End'] as String? ?? '',
      );
}

/// 每周萌王
class TinygrailTopWeek {
  final int id;
  final String name;
  final String avatar;
  final int level;
  final int price;
  final double rate;
  final int sacrifices;
  final int extra;
  final int type;
  final int rank;
  final int rankChange;
  final int extraChange;
  final int typeChange;
  final int assets;

  const TinygrailTopWeek({
    this.id = 0,
    this.name = '',
    this.avatar = '',
    this.level = 0,
    this.price = 0,
    this.rate = 0,
    this.sacrifices = 0,
    this.extra = 0,
    this.type = 0,
    this.rank = 0,
    this.rankChange = 0,
    this.extraChange = 0,
    this.typeChange = 0,
    this.assets = 0,
  });

  factory TinygrailTopWeek.fromJson(Map<String, dynamic> json, {int rank = 0}) =>
      TinygrailTopWeek(
        id: (json['CharacterId'] as num?)?.toInt() ?? 0,
        name: (json['CharacterName'] ?? json['Name'] ?? '') as String? ?? '',
        avatar: json['Avatar'] as String? ?? '',
        level: (json['CharacterLevel'] as num?)?.toInt() ?? 0,
        price: (json['Price'] as num?)?.toInt() ?? 0,
        rate: (json['Rate'] as num?)?.toDouble() ?? 0,
        sacrifices: (json['Sacrifices'] as num?)?.toInt() ?? 0,
        extra: (json['Extra'] as num?)?.toInt() ?? 0,
        type: (json['Type'] as num?)?.toInt() ?? 0,
        rank: rank,
        rankChange: 0,
        extraChange: 0,
        typeChange: 0,
        assets: (json['Assets'] as num?)?.toInt() ?? 0,
      );
}

/// 圣星记录
class TinygrailStarLog {
  final int id;
  final int monoId;
  final String name;
  final String icon;
  final int amount;
  final int stars;
  final int rank;
  final int oldRank;
  final int type;
  final String userId;
  final String userName;
  final String time;

  const TinygrailStarLog({
    this.id = 0,
    this.monoId = 0,
    this.name = '',
    this.icon = '',
    this.amount = 0,
    this.stars = 0,
    this.rank = 0,
    this.oldRank = 0,
    this.type = 0,
    this.userId = '',
    this.userName = '',
    this.time = '',
  });

  factory TinygrailStarLog.fromJson(Map<String, dynamic> json) => TinygrailStarLog(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        monoId: (json['CharacterId'] as num?)?.toInt() ?? 0,
        name: json['CharacterName'] as String? ?? '',
        icon: json['Icon'] as String? ?? '',
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        stars: (json['Stars'] as num?)?.toInt() ?? 0,
        rank: (json['Rank'] as num?)?.toInt() ?? 0,
        oldRank: (json['OldRank'] as num?)?.toInt() ?? 0,
        type: (json['Type'] as num?)?.toInt() ?? 0,
        userId: json['UserName'] as String? ?? '',
        userName: json['Nickname'] as String? ?? '',
        time: json['LogTime'] as String? ?? '',
      );
}

/// 我的道具
class TinygrailItems {
  final int id;
  final String name;
  final String icon;
  final String line;
  final int amount;
  final int last;

  const TinygrailItems({
    this.id = 0,
    this.name = '',
    this.icon = '',
    this.line = '',
    this.amount = 0,
    this.last = 0,
  });

  factory TinygrailItems.fromJson(Map<String, dynamic> json) => TinygrailItems(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        name: json['Name'] as String? ?? '',
        icon: json['Icon'] as String? ?? '',
        line: json['Line'] as String? ?? '',
        amount: (json['Amount'] as num?)?.toInt() ?? 0,
        last: (json['Last'] as num?)?.toInt() ?? 0,
      );
}

/// 圣殿 / 角色圣殿条目
class TinygrailTemple {
  final int id;
  final String name;
  final String nickname;
  final String avatar;
  final String cover;
  final int level;
  final int rank;
  final double rate;
  final int refine;
  final int sacrifices;
  final int assets;
  final int stars;
  final int starForces;
  final int userStarForces;
  final String lastActive;

  const TinygrailTemple({
    this.id = 0,
    this.name = '',
    this.nickname = '',
    this.avatar = '',
    this.cover = '',
    this.level = 0,
    this.rank = 0,
    this.rate = 0,
    this.refine = 0,
    this.sacrifices = 0,
    this.assets = 0,
    this.stars = 0,
    this.starForces = 0,
    this.userStarForces = 0,
    this.lastActive = '',
  });

  factory TinygrailTemple.fromJson(Map<String, dynamic> json) => TinygrailTemple(
        id: (json['CharacterId'] as num?)?.toInt() ?? 0,
        name: (json['CharacterName'] ?? json['Name'] ?? '') as String? ?? '',
        nickname: json['Nickname'] as String? ?? '',
        avatar: json['Avatar'] as String? ?? '',
        cover: json['Cover'] as String? ?? '',
        level: ((json['CharacterLevel'] ?? json['Level'] ?? 0) as num).toInt(),
        rank: (json['CharacterRank'] as num?)?.toInt() ?? 0,
        rate: (json['Rate'] as num?)?.toDouble() ?? 0,
        refine: (json['Refine'] as num?)?.toInt() ?? 0,
        sacrifices: (json['Sacrifices'] as num?)?.toInt() ?? 0,
        assets: (json['Assets'] as num?)?.toInt() ?? 0,
        stars: ((json['CharacterStars'] ?? json['Stars'] ?? 0) as num).toInt(),
        starForces: ((json['CharacterStarForces'] ?? json['StarForces'] ?? 0) as num).toInt(),
        userStarForces: (json['StarForces'] as num?)?.toInt() ?? 0,
        lastActive: json['LastActive'] as String? ?? '',
      );
}

/// 董事会用户
class TinygrailUserBoard {
  final int id;
  final String nickName;
  final String avatar;
  final int balance;
  final String name;
  final int lastIndex;
  final String lastActiveDate;

  const TinygrailUserBoard({
    this.id = 0,
    this.nickName = '',
    this.avatar = '',
    this.balance = 0,
    this.name = '',
    this.lastIndex = 0,
    this.lastActiveDate = '',
  });

  factory TinygrailUserBoard.fromJson(Map<String, dynamic> json) => TinygrailUserBoard(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        nickName: json['Nickname'] as String? ?? '',
        avatar: json['Avatar'] as String? ?? '',
        balance: (json['Balance'] as num?)?.toInt() ?? 0,
        name: json['Name'] as String? ?? '',
        lastIndex: (json['LastIndex'] as num?)?.toInt() ?? 0,
        lastActiveDate: json['LastActiveDate'] as String? ?? '',
      );
}

/// 精炼排行条目
class TinygrailRefine {
  final int monoId;
  final String cover;
  final String name;
  final String userId;
  final String userName;
  final int refine;
  final int assets;
  final int sacrifices;
  final String lastActive;

  const TinygrailRefine({
    this.monoId = 0,
    this.cover = '',
    this.name = '',
    this.userId = '',
    this.userName = '',
    this.refine = 0,
    this.assets = 0,
    this.sacrifices = 0,
    this.lastActive = '',
  });

  factory TinygrailRefine.fromJson(Map<String, dynamic> json) => TinygrailRefine(
        monoId: (json['CharacterId'] as num?)?.toInt() ?? 0,
        cover: json['Cover'] as String? ?? '',
        name: json['CharacterName'] as String? ?? '',
        userId: json['Name'] as String? ?? '',
        userName: json['Nickname'] as String? ?? '',
        refine: (json['Refine'] as num?)?.toInt() ?? 0,
        assets: (json['Assets'] as num?)?.toInt() ?? 0,
        sacrifices: (json['Sacrifices'] as num?)?.toInt() ?? 0,
        lastActive: json['LastActive'] as String? ?? '',
      );
}

/// 搜索条目
class TinygrailSearchItem {
  final int id;
  final String name;
  final int level;
  final bool ico;

  const TinygrailSearchItem({
    this.id = 0,
    this.name = '',
    this.level = 0,
    this.ico = false,
  });

  factory TinygrailSearchItem.fromJson(Map<String, dynamic> json) => TinygrailSearchItem(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        name: json['Name'] as String? ?? '',
        level: (json['Level'] as num?)?.toInt() ?? 0,
        ico: json['ICO'] as bool? ?? false,
      );
}
