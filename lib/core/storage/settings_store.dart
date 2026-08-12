import 'package:flutter/material.dart';
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

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ThemeMode get themeMode {
    final v = _prefs.getString('setting_theme_mode');
    return ThemeMode.values.firstWhere((e) => e.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('setting_theme_mode', mode.name);
    notifyListeners();
  }

  /// 主题色 (默认 bgm 粉, 见 [AppPalette.defaultAccent])
  Color get primaryColor {
    final v = _prefs.getInt('setting_primary_color');
    if (v == null) return AppPalette.defaultAccent;
    return Color(v);
  }

  Future<void> setPrimaryColor(Color color) async {
    await _prefs.setInt('setting_primary_color', color.toARGB32());
    notifyListeners();
  }

  bool get dynamicColor => _prefs.getBool('setting_dynamic_color') ?? false;

  Future<void> setDynamicColor(bool value) async {
    await _prefs.setBool('setting_dynamic_color', value);
    notifyListeners();
  }

  /// 首页显示的 Tab (与原项目 homeRenderTabs 一致)
  List<String> get homeRenderTabs =>
      _prefs.getStringList('setting_home_render_tabs') ??
      const ['Discovery', 'Timeline', 'Home', 'Rakuen', 'User'];

  Future<void> setHomeRenderTabs(List<String> tabs) async {
    await _prefs.setStringList('setting_home_render_tabs', tabs);
    notifyListeners();
  }

  /// 发现页自定义菜单 (启用项 key 列表, null = 全部显示)
  List<String>? get discoveryMenu => _prefs.getStringList('setting_discovery_menu');

  Future<void> setDiscoveryMenu(List<String> keys) async {
    await _prefs.setStringList('setting_discovery_menu', keys);
    notifyListeners();
  }

  Future<void> resetDiscoveryMenu() async {
    await _prefs.remove('setting_discovery_menu');
    notifyListeners();
  }

  String get initialPage => _prefs.getString('setting_initial_page') ?? 'Home';

  Future<void> setInitialPage(String page) async {
    await _prefs.setString('setting_initial_page', page);
    notifyListeners();
  }

  bool get bottomTabLazy => _prefs.getBool('setting_bottom_tab_lazy') ?? true;

  Future<void> setBottomTabLazy(bool value) async {
    await _prefs.setBool('setting_bottom_tab_lazy', value);
    notifyListeners();
  }

  /// 是否开启小圣杯
  bool get tinygrailEnabled => _prefs.getBool('setting_tinygrail') ?? false;

  Future<void> setTinygrailEnabled(bool value) async {
    await _prefs.setBool('setting_tinygrail', value);
    notifyListeners();
  }

  bool get coverFadeIn => _prefs.getBool('setting_cover_fade_in') ?? true;

  Future<void> setCoverFadeIn(bool value) async {
    await _prefs.setBool('setting_cover_fade_in', value);
    notifyListeners();
  }

  /// 封面图片质量: 'grid' | 'small' | 'medium' | 'common' | 'large'
  String get imageQuality => _prefs.getString('setting_image_quality') ?? 'medium';

  Future<void> setImageQuality(String value) async {
    await _prefs.setString('setting_image_quality', value);
    notifyListeners();
  }

  /// 超展开: 屏蔽规则 (用户/小组/条目/人物 id 列表)
  List<String> get rakuenBlockedUsers => _prefs.getStringList('rakuen_block_users') ?? const [];

  Future<void> setRakuenBlockedUsers(List<String> ids) async {
    await _prefs.setStringList('rakuen_block_users', ids);
    notifyListeners();
  }

  List<String> get rakuenBlockedGroups => _prefs.getStringList('rakuen_block_groups') ?? const [];

  Future<void> setRakuenBlockedGroups(List<String> ids) async {
    await _prefs.setStringList('rakuen_block_groups', ids);
    notifyListeners();
  }
}

/// 全局设置 Provider (ChangeNotifier: 修改后自动刷新依赖方)
final settingsStoreProvider = ChangeNotifierProvider<SettingsStore>((ref) {
  return SettingsStore.instance;
});
