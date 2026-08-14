import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/colors.dart';
import '../../shared/widgets/breathing_light.dart';
import '../discovery/discovery_screen.dart';

/// 首页 Tab 开关项 (与原项目 homeRenderTabs 一致)
const kHomeRenderTabOptions = [
  ('Discovery', '发现'),
  ('Timeline', '时间线'),
  ('Home', '首页'),
  ('Rakuen', '超展开'),
  ('User', '我的'),
];

/// 初始页面选项
const kInitialPageOptions = [
  ('Home', '首页'),
  ('Discovery', '发现'),
  ('Timeline', '时间线'),
  ('Rakuen', '超展开'),
  ('User', '我的'),
];

const kImageQualityOptions = [
  ('grid', '网格'),
  ('small', '小'),
  ('medium', '中'),
  ('common', '较大'),
  ('large', '大'),
];

const kHomeCountViewOptions = [
  ('A', '4 / 12'),
  ('B', '4 / 6 (12)'),
  ('C', '4 / 12 (6)'),
  ('D', '4 / 6 / 12'),
];

const kHomeSortingOptions = [
  ('web', '网页'),
  ('onair', '放送'),
  ('default', 'APP'),
];

const kHomeOriginOptions = [('all', '全部'), ('basic', '基本'), ('hide', '隐藏')];

const kHomeAnimeInfoOptions = [(0, '不显示'), (1, '底部'), (2, '行内')];

const kHomeGridCoverOptions = [('square', '正方形'), ('rectangle', '长方形')];

const kProgressHomeTabOptions = [
  ('all', '全部'),
  ('anime', '动画'),
  ('book', '书籍'),
  ('real', '三次元'),
];

const kSubjectBlockOptions = [
  ('showRelation', '前传 / 续作'),
  ('showTags', '标签'),
  ('showSummary', '简介'),
  ('showInfo', '详情'),
  ('showThumbs', '预览图'),
  ('showRating', '评分'),
  ('showCharacter', '角色'),
  ('showStaff', '制作人员'),
  ('showAnitabi', '取景地标'),
  ('showRelations', '关联条目'),
  ('showCatalog', '目录'),
  ('showBlog', '日志'),
  ('showTopic', '帖子'),
  ('showLike', '猜你喜欢'),
  ('showRecent', '动态'),
  ('showComment', '吐槽'),
];

const kSubjectSplitOptions = [
  ('off', '不使用'),
  ('line-1', '分割线 (1)'),
  ('line-2', '分割线 (2)'),
  ('title-main', '标题 (粉)'),
  ('underline-main', '标题 B (粉)'),
  ('title-warning', '标题 (橙)'),
  ('underline-warning', '标题 B (橙)'),
  ('title-primary', '标题 (蓝)'),
  ('underline-primary', '标题 B (蓝)'),
  ('title-success', '标题 (绿)'),
  ('underline-success', '标题 B (绿)'),
];

/// 设置
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            tooltip: '服务状态',
            icon: const Icon(Icons.show_chart),
            onPressed: () => openExternalUrl(kStatusHost),
          ),
          const ServerStatusLight(),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionHeader('外观'),
          _ThemeModeTile(store: store),
          _ColorTile(store: store),
          _SwitchTile(
            title: '动态取色',
            subtitle: '跟随系统动态取色 (Android 12+)',
            value: store.dynamicColor,
            onChanged: (v) => store.setDynamicColor(v),
          ),
          _SwitchTile(
            title: '纯黑',
            subtitle: '深色模式下用纯黑背景',
            value: store.deepDark,
            onChanged: (v) => store.setDeepDark(v),
          ),
          _SwitchTile(
            title: '点击标题切换主题',
            subtitle: '首页和进度页标题点一下切亮暗',
            value: store.logoToggleTheme,
            onChanged: (v) => store.setLogoToggleTheme(v),
          ),

          _SwitchTile(
            title: '封面过渡',
            subtitle: '封面加载淡入动画',
            value: store.coverFadeIn,
            onChanged: (v) => store.setCoverFadeIn(v),
          ),
          _SwitchTile(
            title: '图片加载动画',
            subtitle: '封面占位显示转圈, 卡顿可关',
            value: store.imageSkeleton,
            onChanged: (v) => store.setImageSkeleton(v),
          ),

          _SwitchTile(
            title: '圆形头像',
            subtitle: '关闭则使用圆角方形头像',
            value: store.avatarRound,
            onChanged: (v) => store.setAvatarRound(v),
          ),
          _SwitchTile(
            title: '封面拟物',
            subtitle: '书籍/游戏/音乐封面加类型色边',
            value: store.coverThings,
            onChanged: (v) => store.setCoverThings(v),
          ),
          _SwitchTile(
            title: '震动',
            subtitle: '收藏和进度操作给轻度震动',
            value: store.vibration,
            onChanged: (v) => store.setVibration(v),
          ),
          _SwitchTile(
            title: '看板娘吐槽',
            subtitle: '空列表底部显示 Bangumi 娘',
            value: store.speech,
            onChanged: (v) => store.setSpeech(v),
          ),
          _SwitchTile(
            title: '溢出遮罩',
            subtitle: '横向列表两侧淡出',
            value: store.horizontalShowMask,
            onChanged: (v) => store.setHorizontalShowMask(v),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('字号'),
            subtitle: Text(
              store.fontSizeAdjust == 0
                  ? '默认'
                  : store.fontSizeAdjust > 0
                  ? '+${store.fontSizeAdjust}'
                  : '${store.fontSizeAdjust}',
            ),
            trailing: DropdownButton<int>(
              value: const [-2, -1, 0, 1, 2, 4].contains(store.fontSizeAdjust)
                  ? store.fontSizeAdjust
                  : 0,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: -2, child: Text('-2')),
                DropdownMenuItem(value: -1, child: Text('-1')),
                DropdownMenuItem(value: 0, child: Text('标准')),
                DropdownMenuItem(value: 1, child: Text('+1')),
                DropdownMenuItem(value: 2, child: Text('+2')),
                DropdownMenuItem(value: 4, child: Text('+4')),
              ],
              onChanged: (v) {
                if (v != null) store.setFontSizeAdjust(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.space_bar),
            title: const Text('字间距'),
            trailing: DropdownButton<double>(
              value: store.letterSpacing,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: -1, child: Text('-1')),
                DropdownMenuItem(value: -0.5, child: Text('-0.5')),
                DropdownMenuItem(value: 0, child: Text('标准')),
                DropdownMenuItem(value: 0.5, child: Text('+0.5')),
                DropdownMenuItem(value: 1, child: Text('+1')),
              ],
              onChanged: (v) {
                if (v != null) store.setLetterSpacing(v);
              },
            ),
          ),

          _SectionHeader('定制'),

          _SwitchTile(
            title: '优先中文',
            subtitle: '条目名优先显示中文, 关闭则优先原名',
            value: store.cnFirst,
            onChanged: (v) => store.setCnFirst(v),
          ),
          _SwitchTile(
            title: '隐藏评分',
            subtitle: '列表和详情不显示条目评分',
            value: store.hideScore,
            onChanged: (v) => store.setHideScore(v),
          ),
          _SwitchTile(
            title: '回复显示来源',
            subtitle: '楼层时间后显示客户端或网页来源',
            value: store.showSource,
            onChanged: (v) => store.setShowSource(v),
          ),

          _SwitchTile(
            title: '屏蔽敏感内容',
            subtitle: '条目、时间线、超展开按关键字过滤 NSFW',
            value: store.filter18x,
            onChanged: (v) => store.setFilter18x(v),
          ),
          _SwitchTile(
            title: '屏蔽无头像用户',
            subtitle: '时间线、超展开隐藏默认头像用户',
            value: store.filterDefault,
            onChanged: (v) => store.setFilterDefault(v),
          ),
          _SwitchTile(
            title: '章节讨论热力图',
            subtitle: '章节按钮下方用橙色条表示讨论热度',
            value: store.heatMap,
            onChanged: (v) => store.setHeatMap(v),
          ),
          _SwitchTile(
            title: '打开外链前复制网址',
            subtitle: '跳转外部浏览器前先复制地址',
            value: store.openInfo,
            onChanged: (v) => store.setOpenInfo(v),
          ),
          _SwitchTile(
            title: '用户站龄',
            subtitle: '吐槽和楼层用户名后显示推算站龄',
            value: store.userAge,
            onChanged: (v) => store.setUserAge(v),
          ),
          if (store.userAge)
            ListTile(
              title: const Text('站龄单位'),
              subtitle: const Text('不满一年时可显示月份'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'year', label: Text('年')),
                  ButtonSegment(value: 'month', label: Text('月')),
                ],
                selected: {store.userAgeType},
                onSelectionChanged: (s) => store.setUserAgeType(s.first),
              ),
            ),
          _SwitchTile(
            title: '自动文字排版',
            subtitle: '中文和半形英文、数字之间自动插空',
            value: store.spacing,
            onChanged: (v) => store.setSpacing(v),
          ),
          _SwitchTile(
            title: '时间线先显示缩略',
            subtitle: '点击条目名先弹出简介, 再进详情',
            value: store.timelinePopable,
            onChanged: (v) => store.setTimelinePopable(v),
          ),
          _SectionHeader('时光机'),
          ListTile(
            leading: const Icon(Icons.grid_view),
            title: const Text('网格布局个数'),
            subtitle: const Text('用户空间收藏网格列数'),
            trailing: DropdownButton<int>(
              value: store.userGridNum,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 5, child: Text('5')),
              ],
              onChanged: (v) {
                if (v != null) store.setUserGridNum(v);
              },
            ),
          ),
          _SwitchTile(
            title: '默认列表布局',
            subtitle: '关闭后「我的」收藏默认用网格',
            value: store.userList,
            onChanged: (v) => store.setUserList(v),
          ),
          _SwitchTile(
            title: '网格显示年份',
            subtitle: '网格封面下显示放送年, 动画显示到月',
            value: store.userShowYear,
            onChanged: (v) => store.setUserShowYear(v),
          ),
          _SwitchTile(
            title: '列表分页',
            subtitle: '开启后用分页器翻页, 关闭则加载更多',
            value: store.userPagination,
            onChanged: (v) => store.setUserPagination(v),
          ),
          _SwitchTile(
            title: '显示收藏管理',
            subtitle: '自己的时光机收藏行也显示管理按钮',
            value: store.userShowManage,
            onChanged: (v) => store.setUserShowManage(v),
          ),
          _SwitchTile(
            title: '评论占满布局',
            subtitle: '关闭则吐槽跟在封面右侧旧布局',
            value: store.userCommentsFull,
            onChanged: (v) => store.setUserCommentsFull(v),
          ),
          _SwitchTile(
            title: '空间番剧自动折叠',
            subtitle: '收藏分组同时只展开一项',
            value: store.zoneCollapse,
            onChanged: (v) => store.setZoneCollapse(v),
          ),
          _SwitchTile(
            title: '空间番剧标题居中',
            subtitle: '网格卡片标题居中',
            value: store.zoneAlignCenter,
            onChanged: (v) => store.setZoneAlignCenter(v),
          ),

          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('评论默认展示行数'),
            trailing: DropdownButton<int>(
              value: store.userCommentsLines,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 8, child: Text('8')),
                DropdownMenuItem(value: 100, child: Text('不限制')),
              ],
              onChanged: (v) {
                if (v != null) store.setUserCommentsLines(v);
              },
            ),
          ),

          _SectionHeader('首页'),

          _HomeTabsTile(store: store),
          _InitialPageTile(store: store),
          _SwitchTile(
            title: '底部懒加载',
            subtitle: '切换 Tab 时才加载页面',
            value: store.bottomTabLazy,
            onChanged: (v) => store.setBottomTabLazy(v),
          ),
          _ProgressHomeTabsTile(store: store),
          _SwitchTile(
            title: '显示游戏标签页',
            subtitle: '首页进度显示游戏分类',
            value: store.showGame,
            onChanged: (v) => store.setShowGame(v),
          ),

          _SwitchTile(
            title: '列表紧凑模式',
            subtitle: '首页进度列表更紧凑',
            value: store.homeListCompact,
            onChanged: (v) => store.setHomeListCompact(v),
          ),
          _SwitchTile(
            title: '长篇从最后看过开始',
            subtitle: '展开章节时从最近看过的一集起显示',
            value: store.homeEpStartAtLast,
            onChanged: (v) => store.setHomeEpStartAtLast(v),
          ),
          _HomeCountViewTile(store: store),
          _SwitchTile(
            title: '一直显示放送时间',
            subtitle: '关闭则只在今天/明天放送时显示时刻',
            value: store.homeOnAir,
            onChanged: (v) => store.setHomeOnAir(v),
          ),
          _SwitchTile(
            title: '条目自动下沉',
            subtitle: '已看完已放送章节的条目沉到分组底部',
            value: store.homeSortSink,
            onChanged: (v) => store.setHomeSortSink(v),
          ),

          _HomeSortingTile(store: store),
          _HomeOriginTile(store: store),
          _HomeAnimeInfoTile(store: store),
          _SwitchTile(
            title: '列表搜索框',
            subtitle: '进度页显示筛选入口',
            value: store.homeFilter,
            onChanged: (v) => store.setHomeFilter(v),
          ),
          _SwitchTile(
            title: '网格显示标题',
            subtitle: '宫格封面下方显示条目名',
            value: store.homeGridTitle,
            onChanged: (v) => store.setHomeGridTitle(v),
          ),
          _HomeGridCoverTile(store: store),
          _SwitchTile(
            title: '自动调整章节按钮',
            subtitle: '网格展开时章节少则加宽铺满',
            value: store.homeGridEpAutoAdjust,
            onChanged: (v) => store.setHomeGridEpAutoAdjust(v),
          ),
          _HomeTopCustomTile(
            store: store,
            title: '顶栏左侧入口',
            subtitle: '进度页右侧按钮组左侧, 默认每日放送',
            value: store.homeTopLeftCustom,
            onChanged: store.setHomeTopLeftCustom,
          ),
          _HomeTopCustomTile(
            store: store,
            title: '顶栏右侧入口',
            subtitle: '进度页右侧按钮组右侧, 默认搜索',
            value: store.homeTopRightCustom,
            onChanged: store.setHomeTopRightCustom,
          ),
          _HomeTopCustomTile(
            store: store,
            title: '顶栏额外入口',
            subtitle: '电波提醒旁, 默认不设置',
            value: store.homeTopExtraCustom,
            allowEmpty: true,
            onChanged: store.setHomeTopExtraCustom,
          ),
          _SwitchTile(
            title: '导出 ICS',
            subtitle: '进度右侧菜单和条目更多里增加导出日程',
            value: store.exportICS,
            onChanged: (v) => store.setExportICS(v),
          ),

          _SectionHeader('发现'),
          _DiscoveryMenuNumTile(store: store),
          _SwitchTile(
            title: '今日放送',
            subtitle: '发现页显示今日放送横滑',
            value: store.discoveryTodayOnair,
            onChanged: (v) => store.setDiscoveryTodayOnair(v),
          ),
          _SectionHeader('条目'),
          _SwitchTile(
            title: '其他用户收藏数量',
            subtitle: '条目页显示各收藏状态计数',
            value: store.showCount,
            onChanged: (v) => store.setShowCount(v),
          ),
          _SwitchTile(
            title: '进度输入框',
            subtitle: '条目页显示批量修改进度入口',
            value: store.showEpInput,
            onChanged: (v) => store.setShowEpInput(v),
          ),
          _SwitchTile(
            title: '自定义放送时间块',
            subtitle: '章节区显示可改放送时间',
            value: store.showCustomOnair,
            onChanged: (v) => store.setShowCustomOnair(v),
          ),
          _SwitchTile(
            title: '吐槽项自动换行',
            subtitle: '按斜杠把吐槽拆成多行',
            value: store.commentSplit,
            onChanged: (v) => store.setCommentSplit(v),
          ),
          _SwitchTile(
            title: '发布日期显示到月份',
            subtitle: '关闭则条目页只显示年份',
            value: store.subjectShowAirdayMonth,
            onChanged: (v) => store.setSubjectShowAirdayMonth(v),
          ),
          _SwitchTile(
            title: '简介详情本页展开',
            subtitle: '关闭则点简介/详情进独立页',
            value: store.subjectHtmlExpand,
            onChanged: (v) => store.setSubjectHtmlExpand(v),
          ),
          _SwitchTile(
            title: '详情别名提前',
            subtitle: '信息区把别名挪到中文名后',
            value: store.subjectPromoteAlias,
            onChanged: (v) => store.setSubjectPromoteAlias(v),
          ),
          _SwitchTile(
            title: '条目标签默认展开',
            subtitle: '关闭则标签区先收起',
            value: store.subjectTagsExpand,
            onChanged: (v) => store.setSubjectTagsExpand(v),
          ),
          _SwitchTile(
            title: '关联页显示封面',
            subtitle: '关联条目列表显示封面',
            value: store.subjectLinkCover,
            onChanged: (v) => store.setSubjectLinkCover(v),
          ),
          _SwitchTile(
            title: '关联页显示评分',
            subtitle: '关联条目列表显示全站评分',
            value: store.subjectLinkRating,
            onChanged: (v) => store.setSubjectLinkRating(v),
          ),
          _SwitchTile(
            title: '关联页显示收藏状态',
            subtitle: '进入后额外请求每条收藏, 项多时会慢',
            value: store.subjectLinkCollected,
            onChanged: (v) => store.setSubjectLinkCollected(v),
          ),
          _SwitchTile(
            title: '看过时自动完成进度',
            subtitle: '动画 / 三次元标看过时填满集数',
            value: store.autoCompleteEps,
            onChanged: (v) => store.setAutoCompleteEps(v),
          ),

          ListTile(
            leading: const Icon(Icons.horizontal_rule),
            title: const Text('版块分割线样式'),
            subtitle: const Text('条目页区块之间的分割'),
            trailing: DropdownButton<String>(
              value: store.subjectSplitStyles,
              underline: const SizedBox.shrink(),
              items: [
                for (final (key, label) in kSubjectSplitOptions)
                  DropdownMenuItem(value: key, child: Text(label)),
              ],
              onChanged: (v) {
                if (v != null) store.setSubjectSplitStyles(v);
              },
            ),
          ),
          const _SectionHeader('条目布局'),

          for (final (key, label) in kSubjectBlockOptions)
            _SubjectBlockTile(store: store, blockKey: key, title: label),

          _SectionHeader('图片'),
          _ImageQualityTile(store: store),
          _SectionHeader('功能'),
          _SwitchTile(
            title: '小圣杯',
            subtitle: '在底部显示小圣杯入口',
            value: store.tinygrailEnabled,
            onChanged: (v) => store.setTinygrailEnabled(v),
          ),
          _SwitchTile(
            title: '缩短资产数字',
            subtitle: '小圣杯金额用万 / 亿缩略',
            value: store.xsbShort,
            onChanged: (v) => store.setXsbShort(v),
          ),
          _SwitchTile(
            title: '长按头像看资产',
            subtitle: '全站长按用户头像弹出小圣杯缩略资产',
            value: store.avatarAlertTinygrailAssets,
            onChanged: (v) => store.setAvatarAlertTinygrailAssets(v),
          ),

          _SectionHeader('调试'),
          _SwitchTile(
            title: '调试模式',
            subtitle: '记录 API 请求日志到文件, 便于排查问题',
            value: store.debugLog,
            onChanged: (v) => store.setDebugLog(v),
          ),
          _LinkTile('调试日志', Icons.terminal, '/settings/dev'),
          _SectionHeader('模块'),
          _LinkTile('超展开设置', Icons.forum_outlined, '/rakuen/setting'),
          _LinkTile('源头设置', Icons.link, '/settings/origin'),
          _LinkTile('个人设置', Icons.person_outline, '/settings/user'),
          _SectionHeader('关于与帮助'),
          _LinkTile('关于', Icons.info_outline, '/about'),
          _LinkTile('版本说明', Icons.new_releases_outlined, '/versions'),
          _LinkTile('使用技巧', Icons.lightbulb_outline, '/tips'),
          _LinkTile('使用指南', Icons.menu_book_outlined, '/tips'),
          _LinkTile('代理帮助', Icons.security, '/proxy-help'),
          _LinkTile('Webhook', Icons.webhook, '/webhook'),
          _LinkTile('开发沙盒', Icons.science_outlined, '/playground'),
          _SectionHeader('其他'),
          _LinkTile('站点 Cookie 登录', Icons.cookie_outlined, '/settings/cookies'),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('提示服务可用性'),
            subtitle: const Text('主 Tab 标题旁显示呼吸灯, 对齐原版 notifyServerStatus'),
            trailing: DropdownButton<String>(
              value: store.serverStatusNotify,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('不显示')),
                DropdownMenuItem(value: 'degraded', child: Text('降级时')),
                DropdownMenuItem(value: 'down', child: Text('中断时')),
              ],
              onChanged: (v) {
                if (v != null) store.setServerStatusNotify(v);
              },
            ),
          ),
          _SwitchTile(
            title: '呼吸灯效果',
            subtitle: '服务异常时标题旁闪烁',
            value: store.serverStatusBreathing,
            onChanged: (v) => store.setServerStatusBreathing(v),
          ),
          _LinkTile('服务器状态', Icons.monitor_heart_outlined, '/settings/status'),

          _LinkTile('操作记录', Icons.history, '/settings/actions'),
          _LinkTile('我的卡片', Icons.badge_outlined, '/settings/qiafan'),
          _LinkTile('本地管理', Icons.folder_outlined, '/settings/smb'),
          _LinkTile('本地备份', Icons.inbox_outlined, '/settings/backup'),
          _LinkTile('赞助', Icons.favorite_outline, '/settings/sponsor'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final SettingsStore store;

  const _ThemeModeTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('主题模式'),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
          ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
          ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
        ],
        selected: {store.themeMode},
        onSelectionChanged: (s) => store.setThemeMode(s.first),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final SettingsStore store;

  const _ColorTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.primaryColor;
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题色'),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final color in AppPalette.accentColors)
            InkWell(
              onTap: () => store.setPrimaryColor(color),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color == current
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 2.5,
                        )
                      : null,
                ),
                child: color == current
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeTabsTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeTabsTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final enabled = store.homeRenderTabs;
    return ListTile(
      leading: const Icon(Icons.tab_outlined),
      title: const Text('首页 Tabs'),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (key, label) in kHomeRenderTabOptions)
            FilterChip(
              label: Text(label),
              selected: enabled.contains(key),
              onSelected: (on) {
                final next = [...enabled];
                if (on) {
                  if (!next.contains(key)) next.add(key);
                } else {
                  next.remove(key);
                }
                store.setHomeRenderTabs(next);
              },
            ),
        ],
      ),
    );
  }
}

class _ProgressHomeTabsTile extends StatelessWidget {
  final SettingsStore store;

  const _ProgressHomeTabsTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final enabled = store.homeTabs;
    return ListTile(
      leading: const Icon(Icons.view_week_outlined),
      title: const Text('进度选项卡'),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (key, label) in kProgressHomeTabOptions)
            FilterChip(
              label: Text(label),
              selected: enabled.contains(key),
              onSelected: (on) {
                final next = [...enabled];
                if (on) {
                  if (!next.contains(key)) next.add(key);
                } else if (next.length > 1) {
                  next.remove(key);
                }
                store.setHomeTabs(next);
              },
            ),
        ],
      ),
    );
  }
}

class _InitialPageTile extends StatelessWidget {
  final SettingsStore store;

  const _InitialPageTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.initialPage;
    return ListTile(
      leading: const Icon(Icons.home_outlined),
      title: const Text('初始页面'),
      trailing: DropdownButton<String>(
        value: kInitialPageOptions.any((e) => e.$1 == current)
            ? current
            : 'Home',
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kInitialPageOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setInitialPage(v);
        },
      ),
    );
  }
}

class _DiscoveryMenuNumTile extends StatelessWidget {
  final SettingsStore store;

  const _DiscoveryMenuNumTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.grid_view_outlined),
      title: const Text('菜单每行个数'),
      trailing: DropdownButton<int>(
        value: store.discoveryMenuNum,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 4, child: Text('4')),
          DropdownMenuItem(value: 5, child: Text('5')),
        ],
        onChanged: (v) {
          if (v != null) store.setDiscoveryMenuNum(v);
        },
      ),
    );
  }
}

class _ImageQualityTile extends StatelessWidget {
  final SettingsStore store;

  const _ImageQualityTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.imageQuality;
    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: const Text('图片质量'),
      trailing: DropdownButton<String>(
        value: kImageQualityOptions.any((e) => e.$1 == current)
            ? current
            : 'medium',
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kImageQualityOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setImageQuality(v);
        },
      ),
    );
  }
}

class _HomeCountViewTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeCountViewTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.filter_1_outlined),
      title: const Text('放送数字显示'),
      subtitle: const Text('例: 4 看到 / 6 已放送 / 12 总集数'),
      trailing: DropdownButton<String>(
        value: store.homeCountView,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kHomeCountViewOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setHomeCountView(v);
        },
      ),
    );
  }
}

class _HomeSortingTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeSortingTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sort),
      title: const Text('首页排序'),
      subtitle: const Text('网页=收藏顺序, 放送=今天优先, APP=当季优先'),
      trailing: DropdownButton<String>(
        value: store.homeSorting,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kHomeSortingOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setHomeSorting(v);
        },
      ),
    );
  }
}

class _HomeOriginTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeOriginTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.more_horiz),
      title: const Text('收藏项右侧菜单'),
      subtitle: const Text('全部含源头, 基本只保留置顶等'),
      trailing: DropdownButton<String>(
        value: store.homeOrigin,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kHomeOriginOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setHomeOrigin(v);
        },
      ),
    );
  }
}

class _HomeAnimeInfoTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeAnimeInfoTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('放送及额外信息'),
      subtitle: const Text('播送进度、下一集、季度徽章'),
      trailing: DropdownButton<int>(
        value: store.homeAnimeInfoInline,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kHomeAnimeInfoOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setHomeAnimeInfoInline(v);
        },
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String path;

  const _LinkTile(this.title, this.icon, this.path);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push(path),
    );
  }
}

class _HomeGridCoverTile extends StatelessWidget {
  final SettingsStore store;

  const _HomeGridCoverTile({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.crop_square),
      title: const Text('网格封面形状'),
      subtitle: const Text('宫格布局时的封面比例'),
      trailing: DropdownButton<String>(
        value: store.homeGridCoverLayout,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in kHomeGridCoverOptions)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) store.setHomeGridCoverLayout(v);
        },
      ),
    );
  }
}

class _HomeTopCustomTile extends StatelessWidget {
  final SettingsStore store;
  final String title;
  final String subtitle;
  final String value;
  final bool allowEmpty;
  final ValueChanged<String> onChanged;

  const _HomeTopCustomTile({
    required this.store,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.allowEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (allowEmpty) ('', '不设置'),
      for (final item in kDiscoveryMenus)
        if (item.key != 'Open') (item.key, item.name),
    ];
    final current = items.any((e) => e.$1 == value) ? value : items.first.$1;
    return ListTile(
      leading: const Icon(Icons.tune_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: current,
        underline: const SizedBox.shrink(),
        items: [
          for (final (key, label) in items)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SubjectBlockTile extends StatelessWidget {
  final SettingsStore store;
  final String blockKey;
  final String title;

  const _SubjectBlockTile({
    required this.store,
    required this.blockKey,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final value = store.subjectBlock(blockKey);
    return ListTile(
      title: Text(title),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'show', label: Text('显示')),
          ButtonSegment(value: 'fold', label: Text('折叠')),
          ButtonSegment(value: 'hide', label: Text('隐藏')),
        ],
        selected: {value == 'fold' || value == 'hide' ? value : 'show'},
        onSelectionChanged: (s) => store.setSubjectBlock(blockKey, s.first),
      ),
    );
  }
}
