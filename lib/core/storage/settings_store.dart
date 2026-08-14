import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/colors.dart';

/// 应用设置 (键值对, shared_preferences)
///
/// ChangeNotifier: 所有 setter 修改后调用 [notifyListeners],
/// 使依赖 [settingsStoreProvider] 的 UI (主题等) 立即刷新
class SettingsStore extends ChangeNotifier {
  SettingsStore._();

  /// 应用启动时在 main() 中 init
  static final SettingsStore instance = SettingsStore._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ThemeMode get themeMode {
    final v = _prefs?.getString('setting_theme_mode');
    return ThemeMode.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString('setting_theme_mode', mode.name);
    notifyListeners();
  }

  /// 主题色 (默认 bgm 粉, 见 [AppPalette.defaultAccent])
  Color get primaryColor {
    final v = _prefs?.getInt('setting_primary_color');
    if (v == null) return AppPalette.defaultAccent;
    return Color(v);
  }

  Future<void> setPrimaryColor(Color color) async {
    await _prefs?.setInt('setting_primary_color', color.toARGB32());
    notifyListeners();
  }

  bool get dynamicColor => _prefs?.getBool('setting_dynamic_color') ?? false;

  Future<void> setDynamicColor(bool value) async {
    await _prefs?.setBool('setting_dynamic_color', value);
    notifyListeners();
  }

  /// 首页显示的 Tab (与原项目 homeRenderTabs 一致)
  List<String> get homeRenderTabs =>
      _prefs?.getStringList('setting_home_render_tabs') ??
      const ['Discovery', 'Timeline', 'Home', 'Rakuen', 'User'];

  Future<void> setHomeRenderTabs(List<String> tabs) async {
    await _prefs?.setStringList('setting_home_render_tabs', tabs);
    notifyListeners();
  }

  /// 发现页自定义菜单 (启用项 key 列表, null = 全部显示)
  List<String>? get discoveryMenu =>
      _prefs?.getStringList('setting_discovery_menu');

  Future<void> setDiscoveryMenu(List<String> keys) async {
    await _prefs?.setStringList('setting_discovery_menu', keys);
    notifyListeners();
  }

  Future<void> resetDiscoveryMenu() async {
    await _prefs?.remove('setting_discovery_menu');
    notifyListeners();
  }

  /// 发现页菜单每行个数 (原项目 discoveryMenuNum, 4 或 5)
  int get discoveryMenuNum {
    final n = _prefs?.getInt('setting_discovery_menu_num') ?? 5;
    return n == 4 ? 4 : 5;
  }

  Future<void> setDiscoveryMenuNum(int n) async {
    await _prefs?.setInt('setting_discovery_menu_num', n == 4 ? 4 : 5);
    notifyListeners();
  }

  String get initialPage => _prefs?.getString('setting_initial_page') ?? 'Home';

  Future<void> setInitialPage(String page) async {
    await _prefs?.setString('setting_initial_page', page);
    notifyListeners();
  }

  bool get bottomTabLazy => _prefs?.getBool('setting_bottom_tab_lazy') ?? true;

  Future<void> setBottomTabLazy(bool value) async {
    await _prefs?.setBool('setting_bottom_tab_lazy', value);
    notifyListeners();
  }

  /// 是否开启小圣杯
  bool get tinygrailEnabled => _prefs?.getBool('setting_tinygrail') ?? false;

  Future<void> setTinygrailEnabled(bool value) async {
    await _prefs?.setBool('setting_tinygrail', value);
    notifyListeners();
  }

  bool get coverFadeIn => _prefs?.getBool('setting_cover_fade_in') ?? true;

  Future<void> setCoverFadeIn(bool value) async {
    await _prefs?.setBool('setting_cover_fade_in', value);
    notifyListeners();
  }

  /// 封面图片质量: 'grid' | 'small' | 'medium' | 'common' | 'large'
  String get imageQuality =>
      _prefs?.getString('setting_image_quality') ?? 'medium';

  Future<void> setImageQuality(String value) async {
    await _prefs?.setString('setting_image_quality', value);
    notifyListeners();
  }

  /// 优先中文 (原项目 cnFirst, 默认开)
  bool get cnFirst => _prefs?.getBool('setting_cn_first') ?? true;

  Future<void> setCnFirst(bool value) async {
    await _prefs?.setBool('setting_cn_first', value);
    notifyListeners();
  }

  /// 隐藏评分 (原项目 hideScore)
  bool get hideScore => _prefs?.getBool('setting_hide_score') ?? false;

  Future<void> setHideScore(bool value) async {
    await _prefs?.setBool('setting_hide_score', value);
    notifyListeners();
  }

  /// 屏蔽敏感内容 (原项目 filter18x)
  bool get filter18x => _prefs?.getBool('setting_filter_18x') ?? false;

  Future<void> setFilter18x(bool value) async {
    await _prefs?.setBool('setting_filter_18x', value);
    notifyListeners();
  }

  /// 屏蔽无头像用户相关信息 (原项目 filterDefault)
  bool get filterDefault => _prefs?.getBool('setting_filter_default') ?? false;

  Future<void> setFilterDefault(bool value) async {
    await _prefs?.setBool('setting_filter_default', value);
    notifyListeners();
  }

  /// 章节讨论热力图 (原项目 heatMap, 默认开)
  bool get heatMap => _prefs?.getBool('setting_heat_map') ?? true;

  Future<void> setHeatMap(bool value) async {
    await _prefs?.setBool('setting_heat_map', value);
    notifyListeners();
  }

  /// 打开外部浏览器前复制网址 (原项目 openInfo, 默认开)
  bool get openInfo => _prefs?.getBool('setting_open_info') ?? true;

  Future<void> setOpenInfo(bool value) async {
    await _prefs?.setBool('setting_open_info', value);
    notifyListeners();
  }

  /// 用户站龄 (原项目 userAge, 默认关)
  bool get userAge => _prefs?.getBool('setting_user_age') ?? false;

  Future<void> setUserAge(bool value) async {
    await _prefs?.setBool('setting_user_age', value);
    notifyListeners();
  }

  /// 用户站龄单位: year | month (原项目 userAgeType)
  String get userAgeType =>
      _prefs?.getString('setting_user_age_type') ?? 'year';

  Future<void> setUserAgeType(String value) async {
    await _prefs?.setString(
      'setting_user_age_type',
      value == 'month' ? 'month' : 'year',
    );
    notifyListeners();
  }

  /// 自动文字排版 (原项目 spacing)
  bool get spacing => _prefs?.getBool('setting_spacing') ?? false;

  Future<void> setSpacing(bool value) async {
    await _prefs?.setBool('setting_spacing', value);
    notifyListeners();
  }

  /// 调试模式: 开启后记录 API 请求/响应日志到文件 (设置 → 开发 → 调试日志)
  bool get debugLog => _prefs?.getBool('setting_debug_log') ?? false;

  Future<void> setDebugLog(bool value) async {
    await _prefs?.setBool('setting_debug_log', value);
    notifyListeners();
  }

  /// 超展开: 屏蔽规则 (用户/小组/条目/人物 id 列表)
  List<String> get rakuenBlockedUsers =>
      _prefs?.getStringList('rakuen_block_users') ?? const [];

  Future<void> setRakuenBlockedUsers(List<String> ids) async {
    await _prefs?.setStringList('rakuen_block_users', ids);
    notifyListeners();
  }

  List<String> get rakuenBlockedGroups =>
      _prefs?.getStringList('rakuen_block_groups') ?? const [];

  Future<void> setRakuenBlockedGroups(List<String> ids) async {
    await _prefs?.setStringList('rakuen_block_groups', ids);
    notifyListeners();
  }

  /// 进度页钉住的条目 id
  List<int> get progressPinnedIds =>
      (_prefs?.getStringList('progress_pinned_ids') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();

  Future<void> toggleProgressPinned(int id) async {
    final next = [...progressPinnedIds];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.insert(0, id);
    }
    await _prefs?.setStringList('progress_pinned_ids', [
      for (final e in next) '$e',
    ]);
    notifyListeners();
  }

  bool get progressGrid => _prefs?.getBool('progress_grid') ?? false;

  Future<void> setProgressGrid(bool value) async {
    await _prefs?.setBool('progress_grid', value);
    notifyListeners();
  }

  /// 列表搜索框 (原项目 homeFilter)
  bool get homeFilter => _prefs?.getBool('setting_home_filter') ?? true;

  Future<void> setHomeFilter(bool value) async {
    await _prefs?.setBool('setting_home_filter', value);
    notifyListeners();
  }

  /// 网格条目标题 (原项目 homeGridTitle)
  bool get homeGridTitle => _prefs?.getBool('setting_home_grid_title') ?? true;

  Future<void> setHomeGridTitle(bool value) async {
    await _prefs?.setBool('setting_home_grid_title', value);
    notifyListeners();
  }

  /// 网格封面形状 (原项目 homeGridCoverLayout: square / rectangle)
  String get homeGridCoverLayout {
    final v = _prefs?.getString('setting_home_grid_cover') ?? 'square';
    return v == 'rectangle' ? 'rectangle' : 'square';
  }

  Future<void> setHomeGridCoverLayout(String value) async {
    await _prefs?.setString('setting_home_grid_cover', value);
    notifyListeners();
  }

  /// 进度分类选项卡 (原项目 homeTabs: all/anime/book/real)
  List<String> get homeTabs =>
      _prefs?.getStringList('setting_home_tabs') ??
      const ['all', 'anime', 'book', 'real'];

  Future<void> setHomeTabs(List<String> value) async {
    await _prefs?.setStringList('setting_home_tabs', value);
    notifyListeners();
  }

  /// 网格章节按钮自适应 (原项目 homeGridEpAutoAdjust)
  bool get homeGridEpAutoAdjust =>
      _prefs?.getBool('setting_home_grid_ep_auto') ?? true;

  Future<void> setHomeGridEpAutoAdjust(bool value) async {
    await _prefs?.setBool('setting_home_grid_ep_auto', value);
    notifyListeners();
  }

  /// 进度顶栏左侧入口 (原项目 homeTopLeftCustom, 默认 Calendar)
  String get homeTopLeftCustom =>
      _prefs?.getString('setting_home_top_left') ?? 'Calendar';

  Future<void> setHomeTopLeftCustom(String value) async {
    await _prefs?.setString('setting_home_top_left', value);
    notifyListeners();
  }

  /// 进度顶栏右侧入口 (原项目 homeTopRightCustom, 默认 Search)
  String get homeTopRightCustom =>
      _prefs?.getString('setting_home_top_right') ?? 'Search';

  Future<void> setHomeTopRightCustom(String value) async {
    await _prefs?.setString('setting_home_top_right', value);
    notifyListeners();
  }

  /// 进度顶栏提醒旁额外入口 (原项目 homeTopExtraCustom, 默认空)
  String get homeTopExtraCustom =>
      _prefs?.getString('setting_home_top_extra') ?? '';

  Future<void> setHomeTopExtraCustom(String value) async {
    await _prefs?.setString('setting_home_top_extra', value);
    notifyListeners();
  }

  /// 发现页今日放送 (原项目 discoveryTodayOnair)
  bool get discoveryTodayOnair =>
      _prefs?.getBool('setting_discovery_today_onair') ?? true;

  Future<void> setDiscoveryTodayOnair(bool value) async {
    await _prefs?.setBool('setting_discovery_today_onair', value);
    notifyListeners();
  }

  /// 条目页其他用户收藏数量 (原项目 showCount)
  bool get showCount => _prefs?.getBool('setting_show_count') ?? true;

  Future<void> setShowCount(bool value) async {
    await _prefs?.setBool('setting_show_count', value);
    notifyListeners();
  }

  /// 条目页进度输入框 (原项目 showEpInput)
  bool get showEpInput => _prefs?.getBool('setting_show_ep_input') ?? true;

  Future<void> setShowEpInput(bool value) async {
    await _prefs?.setBool('setting_show_ep_input', value);
    notifyListeners();
  }

  /// 条目页自定义放送时间块 (原项目 showCustomOnair)
  bool get showCustomOnair =>
      _prefs?.getBool('setting_show_custom_onair') ?? true;

  Future<void> setShowCustomOnair(bool value) async {
    await _prefs?.setBool('setting_show_custom_onair', value);
    notifyListeners();
  }

  /// 吐槽项斜杠自动换行 (原项目 commentSplit)
  bool get commentSplit => _prefs?.getBool('setting_comment_split') ?? false;

  Future<void> setCommentSplit(bool value) async {
    await _prefs?.setBool('setting_comment_split', value);
    notifyListeners();
  }

  /// 发布日期显示到月份 (原项目 subjectShowAirdayMonth)
  bool get subjectShowAirdayMonth =>
      _prefs?.getBool('setting_subject_airday_month') ?? true;

  Future<void> setSubjectShowAirdayMonth(bool value) async {
    await _prefs?.setBool('setting_subject_airday_month', value);
    notifyListeners();
  }

  /// 简介详情新页面展开 (原项目 subjectHtmlExpand: true=本页展开)
  bool get subjectHtmlExpand =>
      _prefs?.getBool('setting_subject_html_expand') ?? true;

  Future<void> setSubjectHtmlExpand(bool value) async {
    await _prefs?.setBool('setting_subject_html_expand', value);
    notifyListeners();
  }

  /// 详情别名提前 (原项目 subjectPromoteAlias)
  bool get subjectPromoteAlias =>
      _prefs?.getBool('setting_subject_promote_alias') ?? false;

  Future<void> setSubjectPromoteAlias(bool value) async {
    await _prefs?.setBool('setting_subject_promote_alias', value);
    notifyListeners();
  }

  /// 条目区块: show / fold / hide (原项目 INIT_SUBJECT_LAYOUT)
  String subjectBlock(String key) =>
      _prefs?.getString('setting_subject_block_$key') ?? 'show';

  Future<void> setSubjectBlock(String key, String value) async {
    await _prefs?.setString('setting_subject_block_$key', value);
    notifyListeners();
  }

  /// 放送菜单导出 ICS (原项目 exportICS)
  bool get exportICS => _prefs?.getBool('setting_export_ics') ?? false;

  Future<void> setExportICS(bool value) async {
    await _prefs?.setBool('setting_export_ics', value);
    notifyListeners();
  }

  /// 时间线点条目先显示缩略 (原项目 timelinePopable)
  bool get timelinePopable =>
      _prefs?.getBool('setting_timeline_popable') ?? true;

  Future<void> setTimelinePopable(bool value) async {
    await _prefs?.setBool('setting_timeline_popable', value);
    notifyListeners();
  }

  /// 时光机网格个数 (原项目 userGridNum, 默认 4)
  int get userGridNum {
    final n = _prefs?.getInt('setting_user_grid_num') ?? 4;
    return n == 3 || n == 5 ? n : 4;
  }

  Future<void> setUserGridNum(int value) async {
    await _prefs?.setInt('setting_user_grid_num', value);
    notifyListeners();
  }

  /// 时光机列表布局 (原项目 user/v2 state.list, 默认列表)
  bool get userList => _prefs?.getBool('setting_user_list') ?? true;

  Future<void> setUserList(bool value) async {
    await _prefs?.setBool('setting_user_list', value);
    notifyListeners();
  }

  /// 时光机网格显示年份 (原项目 user/v2 showYear)
  bool get userShowYear => _prefs?.getBool('setting_user_show_year') ?? true;

  Future<void> setUserShowYear(bool value) async {
    await _prefs?.setBool('setting_user_show_year', value);
    notifyListeners();
  }

  /// 时光机列表分页 (原项目 userPagination)
  bool get userPagination => _prefs?.getBool('setting_user_pagination') ?? true;

  Future<void> setUserPagination(bool value) async {
    await _prefs?.setBool('setting_user_pagination', value);
    notifyListeners();
  }

  /// 自己时光机也显示收藏管理 (原项目 userShowManage)
  bool get userShowManage =>
      _prefs?.getBool('setting_user_show_manage') ?? false;

  Future<void> setUserShowManage(bool value) async {
    await _prefs?.setBool('setting_user_show_manage', value);
    notifyListeners();
  }

  /// 时光机评论占满布局 (原项目 userCommentsFull)
  bool get userCommentsFull =>
      _prefs?.getBool('setting_user_comments_full') ?? true;

  Future<void> setUserCommentsFull(bool value) async {
    await _prefs?.setBool('setting_user_comments_full', value);
    notifyListeners();
  }

  /// 时光机评论默认行数 (原项目 userCommentsLines: 4 / 8 / 100)
  int get userCommentsLines {
    final n = _prefs?.getInt('setting_user_comments_lines') ?? 8;
    return n == 4 || n == 100 ? n : 8;
  }

  Future<void> setUserCommentsLines(int value) async {
    await _prefs?.setInt('setting_user_comments_lines', value);
    notifyListeners();
  }

  /// 条目版块分割线 (原项目 subjectSplitStyles)
  String get subjectSplitStyles =>
      _prefs?.getString('setting_subject_split') ?? 'off';

  Future<void> setSubjectSplitStyles(String value) async {
    await _prefs?.setString('setting_subject_split', value);
    notifyListeners();
  }

  /// 封面拟物 (原项目 coverThings)
  bool get coverThings => _prefs?.getBool('setting_cover_things') ?? true;

  Future<void> setCoverThings(bool value) async {
    await _prefs?.setBool('setting_cover_things', value);
    notifyListeners();
  }

  /// 震动反馈 (原项目 vibration)
  bool get vibration => _prefs?.getBool('setting_vibration') ?? false;

  Future<void> setVibration(bool value) async {
    await _prefs?.setBool('setting_vibration', value);
    notifyListeners();
  }

  void haptic([int strength = 1]) {
    if (!vibration) return;
    switch (strength) {
      case 2:
        HapticFeedback.mediumImpact();
      case 3:
        HapticFeedback.heavyImpact();
      default:
        HapticFeedback.lightImpact();
    }
  }

  /// 看板娘吐槽 (原项目 speech)
  bool get speech => _prefs?.getBool('setting_speech') ?? true;

  Future<void> setSpeech(bool value) async {
    await _prefs?.setBool('setting_speech', value);
    notifyListeners();
  }

  /// 字号加减 (原项目 fontSizeAdjust, -2..4)
  int get fontSizeAdjust {
    final n = _prefs?.getInt('setting_font_size_adjust') ?? 0;
    return n.clamp(-2, 4);
  }

  Future<void> setFontSizeAdjust(int value) async {
    await _prefs?.setInt('setting_font_size_adjust', value.clamp(-2, 4));
    notifyListeners();
  }

  /// 字间距 (原项目 letterSpacing, -1 / -0.5 / 0 / 0.5 / 1)
  double get letterSpacing {
    final v = _prefs?.getDouble('setting_letter_spacing') ?? 0;
    return v.clamp(-1.0, 1.0);
  }

  Future<void> setLetterSpacing(double value) async {
    await _prefs?.setDouble('setting_letter_spacing', value.clamp(-1.0, 1.0));
    notifyListeners();
  }

  /// 横向列表溢出遮罩 (原项目 horizontalShowMask)
  bool get horizontalShowMask =>
      _prefs?.getBool('setting_horizontal_show_mask') ?? false;

  Future<void> setHorizontalShowMask(bool value) async {
    await _prefs?.setBool('setting_horizontal_show_mask', value);
    notifyListeners();
  }

  /// 回复显示来源 (原项目 source)
  bool get showSource => _prefs?.getBool('setting_show_source') ?? false;

  Future<void> setShowSource(bool value) async {
    await _prefs?.setBool('setting_show_source', value);
    notifyListeners();
  }

  /// 空间番剧自动折叠 (原项目 zoneCollapse)
  bool get zoneCollapse => _prefs?.getBool('setting_zone_collapse') ?? false;

  Future<void> setZoneCollapse(bool value) async {
    await _prefs?.setBool('setting_zone_collapse', value);
    notifyListeners();
  }

  /// 空间番剧标题居中 (原项目 zoneAlignCenter)
  bool get zoneAlignCenter =>
      _prefs?.getBool('setting_zone_align_center') ?? true;

  Future<void> setZoneAlignCenter(bool value) async {
    await _prefs?.setBool('setting_zone_align_center', value);
    notifyListeners();
  }

  /// 看过时自动完成所有进度 (原项目 autoCompleteEps)
  bool get autoCompleteEps =>
      _prefs?.getBool('setting_auto_complete_eps') ?? false;

  Future<void> setAutoCompleteEps(bool value) async {
    await _prefs?.setBool('setting_auto_complete_eps', value);
    notifyListeners();
  }

  /// 读过时自动完成章节和卷 (原项目 autoCompleteBooks)
  bool get autoCompleteBooks =>
      _prefs?.getBool('setting_auto_complete_books') ?? false;

  Future<void> setAutoCompleteBooks(bool value) async {
    await _prefs?.setBool('setting_auto_complete_books', value);
    notifyListeners();
  }

  /// 条目标签默认展开 (原项目 subjectTagsExpand)
  bool get subjectTagsExpand =>
      _prefs?.getBool('setting_subject_tags_expand') ?? true;

  Future<void> setSubjectTagsExpand(bool value) async {
    await _prefs?.setBool('setting_subject_tags_expand', value);
    notifyListeners();
  }

  /// 关联页显示封面 (原项目 subjectLinkCover)
  bool get subjectLinkCover =>
      _prefs?.getBool('setting_subject_link_cover') ?? true;

  Future<void> setSubjectLinkCover(bool value) async {
    await _prefs?.setBool('setting_subject_link_cover', value);
    notifyListeners();
  }

  /// 关联页显示评分 (原项目 subjectLinkRating)
  bool get subjectLinkRating =>
      _prefs?.getBool('setting_subject_link_rating') ?? true;

  Future<void> setSubjectLinkRating(bool value) async {
    await _prefs?.setBool('setting_subject_link_rating', value);
    notifyListeners();
  }

  /// 黑暗模式纯黑 (原项目 deepDark)
  bool get deepDark => _prefs?.getBool('setting_deep_dark') ?? true;

  Future<void> setDeepDark(bool value) async {
    await _prefs?.setBool('setting_deep_dark', value);
    notifyListeners();
  }

  /// 图片加载骨架屏 (原项目 imageSkeleton)
  bool get imageSkeleton => _prefs?.getBool('setting_image_skeleton') ?? true;

  Future<void> setImageSkeleton(bool value) async {
    await _prefs?.setBool('setting_image_skeleton', value);
    notifyListeners();
  }

  /// 长按头像显示小圣杯资产 (原项目 avatarAlertTinygrailAssets)
  bool get avatarAlertTinygrailAssets =>
      _prefs?.getBool('setting_avatar_alert_tinygrail') ?? false;

  Future<void> setAvatarAlertTinygrailAssets(bool value) async {
    await _prefs?.setBool('setting_avatar_alert_tinygrail', value);
    notifyListeners();
  }

  /// 关联页显示收藏状态 (原项目 subjectLinkCollected)
  bool get subjectLinkCollected =>
      _prefs?.getBool('setting_subject_link_collected') ?? false;

  Future<void> setSubjectLinkCollected(bool value) async {
    await _prefs?.setBool('setting_subject_link_collected', value);
    notifyListeners();
  }

  /// 点击顶部标题切换主题 (原项目 logoToggleTheme)
  bool get logoToggleTheme =>
      _prefs?.getBool('setting_logo_toggle_theme') ?? false;

  Future<void> setLogoToggleTheme(bool value) async {
    await _prefs?.setBool('setting_logo_toggle_theme', value);
    notifyListeners();
  }

  /// 小圣杯缩短资产数字 (原项目 xsbShort)
  bool get xsbShort => _prefs?.getBool('setting_xsb_short') ?? true;

  Future<void> setXsbShort(bool value) async {
    await _prefs?.setBool('setting_xsb_short', value);
    notifyListeners();
  }

  Future<void> toggleThemeMode() {
    final next = switch (themeMode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark,
    };
    return setThemeMode(next);
  }

  /// 首页 LOGO 旁显示服务可用性 (原项目 serverStatus: none/degraded/down)
  String get serverStatusNotify =>
      _prefs?.getString('setting_server_status') ?? 'down';

  Future<void> setServerStatusNotify(String value) async {
    await _prefs?.setString('setting_server_status', value);
    notifyListeners();
  }

  /// 服务可用性呼吸灯 (原项目 serverStatusBreathing)
  bool get serverStatusBreathing =>
      _prefs?.getBool('setting_server_status_breathing') ?? true;

  Future<void> setServerStatusBreathing(bool value) async {
    await _prefs?.setBool('setting_server_status_breathing', value);
    notifyListeners();
  }

  /// 圆形头像 (原项目 avatarRound)
  bool get avatarRound => _prefs?.getBool('setting_avatar_round') ?? false;

  Future<void> setAvatarRound(bool value) async {
    await _prefs?.setBool('setting_avatar_round', value);
    notifyListeners();
  }

  /// 首页显示游戏标签页 (原项目 showGame)
  bool get showGame => _prefs?.getBool('setting_show_game') ?? false;

  Future<void> setShowGame(bool value) async {
    await _prefs?.setBool('setting_show_game', value);
    notifyListeners();
  }

  /// 首页列表紧凑 (原项目 homeListCompact)
  bool get homeListCompact =>
      _prefs?.getBool('setting_home_list_compact') ?? false;

  Future<void> setHomeListCompact(bool value) async {
    await _prefs?.setBool('setting_home_list_compact', value);
    notifyListeners();
  }

  /// 长篇动画从最后看过开始显示 (原项目 homeEpStartAtLastWathed)
  bool get homeEpStartAtLast =>
      _prefs?.getBool('setting_home_ep_start_at_last') ?? true;

  Future<void> setHomeEpStartAtLast(bool value) async {
    await _prefs?.setBool('setting_home_ep_start_at_last', value);
    notifyListeners();
  }

  /// 首页放送数字显示 (原项目 homeCountView: A/B/C/D)
  String get homeCountView {
    final v = _prefs?.getString('setting_home_count_view') ?? 'A';
    return switch (v) {
      'B' || 'C' || 'D' => v,
      _ => 'A',
    };
  }

  Future<void> setHomeCountView(String value) async {
    await _prefs?.setString('setting_home_count_view', value);
    notifyListeners();
  }

  /// 一直显示放送时间 (原项目 homeOnAir)
  bool get homeOnAir => _prefs?.getBool('setting_home_onair') ?? false;

  Future<void> setHomeOnAir(bool value) async {
    await _prefs?.setBool('setting_home_onair', value);
    notifyListeners();
  }

  /// 条目自动下沉 (原项目 homeSortSink)
  bool get homeSortSink => _prefs?.getBool('setting_home_sort_sink') ?? true;

  Future<void> setHomeSortSink(bool value) async {
    await _prefs?.setBool('setting_home_sort_sink', value);
    notifyListeners();
  }

  /// 首页排序 (原项目 homeSorting: web / onair / default)
  String get homeSorting {
    final v = _prefs?.getString('setting_home_sorting') ?? 'web';
    return switch (v) {
      'onair' || 'default' => v,
      _ => 'web',
    };
  }

  Future<void> setHomeSorting(String value) async {
    await _prefs?.setString('setting_home_sorting', value);
    notifyListeners();
  }

  /// 首页右侧菜单 (原项目 homeOrigin: all / basic / hide)
  String get homeOrigin {
    final v = _prefs?.getString('setting_home_origin') ?? 'hide';
    return switch (v) {
      'all' || 'basic' => v,
      _ => 'hide',
    };
  }

  Future<void> setHomeOrigin(String value) async {
    await _prefs?.setString('setting_home_origin', value);
    notifyListeners();
  }

  /// 放送及额外信息 (原项目 homeAnimeInfoInline: 0=不显示 1=底部 2=行内)
  int get homeAnimeInfoInline {
    final v = _prefs?.getInt('setting_home_anime_info') ?? 1;
    return v == 0 || v == 2 ? v : 1;
  }

  Future<void> setHomeAnimeInfoInline(int value) async {
    await _prefs?.setInt('setting_home_anime_info', value);
    notifyListeners();
  }

  /// 时间线临时隐藏: userId -> 到期毫秒

  Map<String, int> get timelineHiddenUntil {
    final raw = _prefs?.getStringList('timeline_hidden_until') ?? const [];
    final map = <String, int>{};
    for (final e in raw) {
      final parts = e.split('|');
      if (parts.length != 2) continue;
      final until = int.tryParse(parts[1]);
      if (until == null) continue;
      map[parts[0]] = until;
    }
    return map;
  }

  bool isTimelineUserHidden(String userId) {
    if (userId.isEmpty) return false;
    final until = timelineHiddenUntil[userId];
    if (until == null) return false;
    return until > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> hideTimelineUser(String userId, int days) async {
    final next = Map<String, int>.from(timelineHiddenUntil);
    next[userId] = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    await _prefs?.setStringList('timeline_hidden_until', [
      for (final e in next.entries) '${e.key}|${e.value}',
    ]);
    notifyListeners();
  }

  /// 自定义放送: subjectId -> "weekday|HHMM" (weekday: 0=周日)
  Map<int, String> get customOnAir {
    final raw = _prefs?.getStringList('custom_onair') ?? const [];
    final map = <int, String>{};
    for (final e in raw) {
      final i = e.indexOf('|');
      if (i <= 0) continue;
      final id = int.tryParse(e.substring(0, i));
      if (id == null) continue;
      map[id] = e.substring(i + 1);
    }
    return map;
  }

  String? customOnAirOf(int subjectId) => customOnAir[subjectId];

  Future<void> setCustomOnAir(int subjectId, int weekday, String hhmm) async {
    final next = Map<int, String>.from(customOnAir);
    next[subjectId] = '$weekday|$hhmm';
    await _prefs?.setStringList('custom_onair', [
      for (final e in next.entries) '${e.key}|${e.value}',
    ]);
    notifyListeners();
  }

  Future<void> clearCustomOnAir(int subjectId) async {
    final next = Map<int, String>.from(customOnAir)..remove(subjectId);
    await _prefs?.setStringList('custom_onair', [
      for (final e in next.entries) '${e.key}|${e.value}',
    ]);
    notifyListeners();
  }

  /// 用户备注 (原项目 setting.userRemark)
  Map<String, String> get userRemarks {
    final raw = _prefs?.getStringList('user_remarks') ?? const [];
    final map = <String, String>{};
    for (final e in raw) {
      final i = e.indexOf('|');
      if (i <= 0) continue;
      map[e.substring(0, i)] = e.substring(i + 1);
    }
    return map;
  }

  String userRemarkOf(String userId) => userRemarks[userId] ?? '';

  Future<void> setUserRemark(String userId, String text) async {
    if (userId.isEmpty) return;
    final next = Map<String, String>.from(userRemarks);
    final value = text.trim();
    if (value.isEmpty) {
      next.remove(userId);
    } else {
      next[userId] = value;
    }
    await _prefs?.setStringList('user_remarks', [
      for (final e in next.entries) '${e.key}|${e.value}',
    ]);
    notifyListeners();
  }
}

/// 全局设置 Provider (ChangeNotifier: 修改后自动刷新依赖方)
final settingsStoreProvider = ChangeNotifierProvider<SettingsStore>((ref) {
  return SettingsStore.instance;
});
