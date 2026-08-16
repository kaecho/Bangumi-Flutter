import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/cache.dart';

/// 超展开设置 (移植自原项目 stores/rakuen/init.ts INIT_SETTING)
///
/// 持久化: hive box 'rakuen', key 'settings' (单个 JSON map)
class RakuenSettingsState {
  /// 屏蔽的用户 (displayName)
  final List<String> blockUsers;

  /// 屏蔽的小组/条目/人物 (对帖子所属小组名生效)
  final List<String> blockGroups;

  /// 屏蔽的关键词 (匹配帖子标题/楼层内容)
  final List<String> blockKeywords;

  /// 屏蔽默认头像用户的帖子
  final bool blockDefaultUser;

  /// 楼层样式: A=角标 B=红点 C=背景 D=不设置
  final String floorStyle;

  /// 展开引用 (子回复中的上级引用)
  final bool quote;

  /// 显示引用头像
  final bool quoteAvatar;

  /// 子楼层折叠: 0=一直折叠 2/4/8=超过后折叠
  final String subExpand;

  /// 楼层加宽展示
  final bool wide;

  /// 楼层中图片自动加载: 0=不加载 200/2000/10000=阈值(px)
  final String autoLoadImage;

  /// 过滤用户删除的楼层
  final bool filterDelete;

  /// 标记坟贴 (>90 天未回复)
  final bool markOldTopic;

  /// 显示长楼层收起按钮
  final bool showFoldButton;

  /// 贴贴模块 (原项目 likes)
  final bool likes;

  /// 楼层直达条 (原项目 scrollDirection: none/left/bottom/right)
  final String scrollDirection;

  /// 楼层链接显示成信息块 (原项目 matchLink)
  final bool matchLink;

  /// 大表情尺寸 (原项目 bigEmojiSize: 28/36/48)
  final int bigEmojiSize;

  /// 楼层跳转滚动动画 (原项目 sliderAnimated)
  final bool sliderAnimated;

  /// 交换跳转按钮 (原项目 switchSlider)
  final bool switchSlider;

  /// 长楼层漂浮收起 (原项目 showFixedToggleFloorBtn)
  final bool showFixedToggleFloorBtn;

  /// 追踪特定用户回复 (原项目 commentTrack)
  final List<String> commentTrack;

  const RakuenSettingsState({
    this.blockUsers = const [],
    this.blockGroups = const [],
    this.blockKeywords = const [],
    this.blockDefaultUser = false,
    this.floorStyle = 'A',
    this.quote = true,
    this.quoteAvatar = true,
    this.subExpand = '4',
    this.wide = false,
    this.autoLoadImage = '200',
    this.filterDelete = true,
    this.markOldTopic = true,
    this.showFoldButton = false,
    this.likes = true,
    this.scrollDirection = 'bottom',
    this.matchLink = false,
    this.bigEmojiSize = 36,
    this.sliderAnimated = true,
    this.switchSlider = false,
    this.showFixedToggleFloorBtn = false,
    this.commentTrack = const [],
  });

  bool isTracked(String userId) =>
      userId.isNotEmpty && commentTrack.contains(userId);

  /// 楼层图片是否加载 (autoLoadImage != '0')
  bool get loadImages => autoLoadImage != '0';

  /// 是否折叠该用户的楼层 (屏蔽用户)
  bool isUserBlocked(String userId, [String userName = '']) {
    if (userId.isEmpty && userName.isEmpty) return false;
    for (final item in blockUsers) {
      if (item == userId || item == userName) return true;
      if (userId.isNotEmpty && item.endsWith('@$userId')) return true;
      if (userName.isNotEmpty && item.startsWith('$userName@')) return true;
    }
    return false;
  }

  /// 是否屏蔽该小组的帖子
  bool isGroupBlocked(String group) {
    if (group.isEmpty) return false;
    return blockGroups.any((g) => g == group);
  }

  /// 是否命中屏蔽关键词
  bool matchesKeyword(String text) {
    return blockKeywords.any(text.contains);
  }

  RakuenSettingsState copyWith({
    List<String>? blockUsers,
    List<String>? blockGroups,
    List<String>? blockKeywords,
    bool? blockDefaultUser,
    String? floorStyle,
    bool? quote,
    bool? quoteAvatar,
    String? subExpand,
    bool? wide,
    String? autoLoadImage,
    bool? filterDelete,
    bool? markOldTopic,
    bool? showFoldButton,
    bool? likes,
    String? scrollDirection,
    bool? matchLink,
    int? bigEmojiSize,
    bool? sliderAnimated,
    bool? switchSlider,
    bool? showFixedToggleFloorBtn,
    List<String>? commentTrack,
  }) => RakuenSettingsState(
    blockUsers: blockUsers ?? this.blockUsers,
    blockGroups: blockGroups ?? this.blockGroups,
    blockKeywords: blockKeywords ?? this.blockKeywords,
    blockDefaultUser: blockDefaultUser ?? this.blockDefaultUser,
    floorStyle: floorStyle ?? this.floorStyle,
    quote: quote ?? this.quote,
    quoteAvatar: quoteAvatar ?? this.quoteAvatar,
    subExpand: subExpand ?? this.subExpand,
    wide: wide ?? this.wide,
    autoLoadImage: autoLoadImage ?? this.autoLoadImage,
    filterDelete: filterDelete ?? this.filterDelete,
    markOldTopic: markOldTopic ?? this.markOldTopic,
    showFoldButton: showFoldButton ?? this.showFoldButton,
    likes: likes ?? this.likes,
    scrollDirection: scrollDirection ?? this.scrollDirection,
    matchLink: matchLink ?? this.matchLink,
    bigEmojiSize: bigEmojiSize ?? this.bigEmojiSize,
    sliderAnimated: sliderAnimated ?? this.sliderAnimated,
    switchSlider: switchSlider ?? this.switchSlider,
    showFixedToggleFloorBtn:
        showFixedToggleFloorBtn ?? this.showFixedToggleFloorBtn,
    commentTrack: commentTrack ?? this.commentTrack,
  );

  Map<String, dynamic> toJson() => {
    'blockUsers': blockUsers,
    'blockGroups': blockGroups,
    'blockKeywords': blockKeywords,
    'blockDefaultUser': blockDefaultUser,
    'floorStyle': floorStyle,
    'quote': quote,
    'quoteAvatar': quoteAvatar,
    'subExpand': subExpand,
    'wide': wide,
    'autoLoadImage': autoLoadImage,
    'filterDelete': filterDelete,
    'markOldTopic': markOldTopic,
    'showFoldButton': showFoldButton,
    'likes': likes,
    'scrollDirection': scrollDirection,
    'matchLink': matchLink,
    'bigEmojiSize': bigEmojiSize,
    'sliderAnimated': sliderAnimated,
    'switchSlider': switchSlider,
    'showFixedToggleFloorBtn': showFixedToggleFloorBtn,
    'commentTrack': commentTrack,
  };

  factory RakuenSettingsState.fromJson(Map<String, dynamic> json) =>
      RakuenSettingsState(
        blockUsers: _stringList(json['blockUsers']),
        blockGroups: _stringList(json['blockGroups']),
        blockKeywords: _stringList(json['blockKeywords']),
        blockDefaultUser: json['blockDefaultUser'] as bool? ?? false,
        floorStyle: json['floorStyle'] as String? ?? 'A',
        quote: json['quote'] as bool? ?? true,
        quoteAvatar: json['quoteAvatar'] as bool? ?? true,
        subExpand: json['subExpand'] as String? ?? '4',
        wide: json['wide'] as bool? ?? false,
        autoLoadImage: json['autoLoadImage'] as String? ?? '200',
        filterDelete: json['filterDelete'] as bool? ?? true,
        markOldTopic: json['markOldTopic'] as bool? ?? true,
        showFoldButton: json['showFoldButton'] as bool? ?? false,
        likes: json['likes'] as bool? ?? true,
        scrollDirection: json['scrollDirection'] as String? ?? 'bottom',
        matchLink: json['matchLink'] as bool? ?? false,
        bigEmojiSize: (json['bigEmojiSize'] as num?)?.toInt() ?? 36,
        sliderAnimated: json['sliderAnimated'] as bool? ?? true,
        switchSlider: json['switchSlider'] as bool? ?? false,
        showFixedToggleFloorBtn:
            json['showFixedToggleFloorBtn'] as bool? ?? false,
        commentTrack: _stringList(json['commentTrack']),
      );

  static List<String> _stringList(dynamic v) =>
      v is List ? v.whereType<String>().toList() : const [];
}

/// 超展开设置 Provider (hive 持久化)
final rakuenSettingsProvider =
    NotifierProvider<RakuenSettings, RakuenSettingsState>(RakuenSettings.new);

class RakuenSettings extends Notifier<RakuenSettingsState> {
  static const _boxName = 'rakuen';
  static const _key = 'settings';

  @override
  RakuenSettingsState build() {
    final raw = Cache.instance.get(
      _boxName,
      _key,
      maxAge: const Duration(days: 3650),
    );
    if (raw is String && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return RakuenSettingsState.fromJson(json);
      } catch (_) {}
    }
    return const RakuenSettingsState();
  }

  Future<void> _save(RakuenSettingsState next) async {
    state = next;
    await Cache.instance.put(_boxName, _key, jsonEncode(next.toJson()));
  }

  Future<void> setBool(String key, bool value) async {
    final next = state.copyWith(
      blockDefaultUser: key == 'blockDefaultUser' ? value : null,
      quote: key == 'quote' ? value : null,
      quoteAvatar: key == 'quoteAvatar' ? value : null,
      wide: key == 'wide' ? value : null,
      filterDelete: key == 'filterDelete' ? value : null,
      markOldTopic: key == 'markOldTopic' ? value : null,
      showFoldButton: key == 'showFoldButton' ? value : null,
      likes: key == 'likes' ? value : null,
      matchLink: key == 'matchLink' ? value : null,
      sliderAnimated: key == 'sliderAnimated' ? value : null,
      switchSlider: key == 'switchSlider' ? value : null,
      showFixedToggleFloorBtn: key == 'showFixedToggleFloorBtn' ? value : null,
    );

    if (next != state) await _save(next);
  }

  Future<void> setString(String key, String value) async {
    final next = state.copyWith(
      floorStyle: key == 'floorStyle' ? value : null,
      subExpand: key == 'subExpand' ? value : null,
      autoLoadImage: key == 'autoLoadImage' ? value : null,
      scrollDirection: key == 'scrollDirection' ? value : null,
    );

    if (next != state) await _save(next);
  }

  Future<void> setBigEmojiSize(int value) async {
    await _save(state.copyWith(bigEmojiSize: value));
  }

  Future<void> addBlockUser(String userId) async {
    if (state.blockUsers.contains(userId)) return;
    await _save(state.copyWith(blockUsers: [...state.blockUsers, userId]));
  }

  Future<void> removeBlockUser(String userId) async {
    await _save(
      state.copyWith(
        blockUsers: state.blockUsers.where((e) => e != userId).toList(),
      ),
    );
  }

  Future<void> trackUser(String userId) async {
    if (userId.isEmpty || state.commentTrack.contains(userId)) return;
    await _save(state.copyWith(commentTrack: [...state.commentTrack, userId]));
  }

  Future<void> untrackUser(String userId) async {
    await _save(
      state.copyWith(
        commentTrack: state.commentTrack.where((e) => e != userId).toList(),
      ),
    );
  }

  Future<void> toggleTrackUser(String userId) async {
    if (state.isTracked(userId)) {
      await untrackUser(userId);
    } else {
      await trackUser(userId);
    }
  }

  Future<void> addBlockGroup(String group) async {
    if (state.blockGroups.contains(group)) return;
    await _save(state.copyWith(blockGroups: [...state.blockGroups, group]));
  }

  Future<void> removeBlockGroup(String group) async {
    await _save(
      state.copyWith(
        blockGroups: state.blockGroups.where((e) => e != group).toList(),
      ),
    );
  }

  Future<void> addBlockKeyword(String keyword) async {
    if (state.blockKeywords.contains(keyword)) return;
    await _save(
      state.copyWith(blockKeywords: [...state.blockKeywords, keyword]),
    );
  }

  Future<void> removeBlockKeyword(String keyword) async {
    await _save(
      state.copyWith(
        blockKeywords: state.blockKeywords.where((e) => e != keyword).toList(),
      ),
    );
  }
}

/// 楼层样式选项 (移植自原项目 RAKUEN_NEW_FLOOR_STYLE)
const kFloorStyleOptions = [
  ('角标', 'A'),
  ('红点', 'B'),
  ('背景', 'C'),
  ('不设置', 'D'),
];

/// 子楼层折叠选项 (RAKUEN_SUB_EXPAND)
const kSubExpandOptions = ['0', '2', '4', '8'];

/// 图片自动加载选项 (RAKUEN_AUTO_LOAD_IMAGE)
const kAutoLoadImageOptions = [
  ('不加载', '0'),
  ('0.2m', '200'),
  ('2m', '2000'),
  ('自动', '10000'),
];

/// 楼层直达条方向 (原项目 RAKUEN_SCROLL_DIRECTION)
const kScrollDirectionOptions = [
  ('隐藏', 'none'),
  ('左侧', 'left'),
  ('底部', 'bottom'),
  ('右侧', 'right'),
];
