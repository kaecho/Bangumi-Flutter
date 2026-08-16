# Bangumi Flutter Rewrite — Architecture & Porting Guide

This document is the single source of truth for the Flutter rewrite of
https://github.com/czy0729/Bangumi (RN/Expo app, v8.38.2). Goal: 1:1 feature
parity, latest stable Flutter (3.44.x), enterprise structure, CI/CD.

## Source of truth (original repo)

The original is cloned read-only at `/tmp/bangumi-orig`. Key dirs:
- `src/screens/*` — screens (RN), `src/components/*` — shared components
- `src/constants/api/index.ts` — ALL API endpoint templates
- `src/utils/fetch.p1/*`, `src/utils/fetch.v0/*` — API v1/v0 request layers
- `src/utils/html/*` — HTML parsing for forum/topic rendering
- `src/stores/*` — mobx stores (state logic to port)
- `web/CHANGELOG.MD` — feature history

## Tech stack (pin via `flutter pub add` at scaffold time)

- Flutter 3.44.9 stable; branded tokens + original chrome (not default Material You)

- `flutter_riverpod` — state management (plain providers, NO codegen)
- `go_router` — routing; **每个 feature 维护自己的 `*_routes.dart`**, router.dart 聚合
- `dio` — HTTP (interceptors: auth token, host fallback api.bgmapi.com → api.bgm.tv)
- **models: 手写不可变 class + fromJson (无 freezed/build_runner)**, 放 shared/models/ 或 feature 内
- `shared_preferences` — settings; `hive_ce` — cache
- `cached_network_image` — images
- `webview_flutter` — OAuth login + web-view screens
- `flutter_html` — rendering HTML in topics/blogs (rakuen)
- `fl_chart` — rank/yearbook charts
- `url_launcher`, `share_plus`, `photo_view`, `intl`

## Project layout (enterprise, feature-first)

```
lib/
  main.dart
  app/
    app.dart            — MaterialApp.router, theme wiring
    router.dart         — ALL routes (go_router), tab shell
    theme.dart          — light/dark + accent colors (Material 3)
  core/
    api/
      api_client.dart   — dio singleton, base URL, auth interceptor
      api_endpoints.dart— endpoint templates (port of constants/api)
    auth/
      auth_controller.dart — Riverpod provider: token, user, login/logout
    storage/
      settings_store.dart   — shared_preferences wrapper
      cache.dart            — hive boxes
    utils/              — date fmt, string helpers, html strip
  features/
    discovery/          — 每日放送 calendar, search, rank, anime, staff,
                          catalog(+detail), yearbook, tags, blogs, groups,
                          series, recommend, like, pic, wiki, channel, vib,
                          typerank, award, bi-weekly, dollars, game, manga,
                          hentai, nsfw, users, adv, browser, character, anitama
    subject/            — subject detail + all sub-pages (overview, info,
                          episodes, characters, persons, rating, preview,
                          tag, typerank, works, mono, wiki, voices, link,
                          catalogs) + collection management
    progress/           — Home tab: 收藏进度 (tabs 全部/动画/书籍/三次元/游戏)
    timeline/           — 时间线 + say(吐槽)
    rakuen/             — 超展开: board, group, topic, blog, reviews, notify,
                          history, mine, search, setting (block rules)
    user/               — login, zone(用户空间), 时光机, milestone(照片墙),
                          blogs, catalogs, friends, pm(短信), setting,
                          backup, smb(本地文件夹), user-setting,
                          origin-setting, server-status, sponsor, actions, dev
    tinygrail/          — 小圣杯 game module (~30 screens)
    webview/            — web-browser, bilibili-sync, douban-sync, share,
                          versions, tips, proxy-help, webhook, log
  shared/
    widgets/            — Cover, Score, Stars, Tag, SectionHeader, Empty,
                          Loading, Avatar, BlurHeader, StatusBar, etc.
    models/             — Subject, Collection, User, Ep, Topic, ... (freezed)
```

## Conventions (MANDATORY)

1. **Naming**: files `snake_case.dart`, widgets `PascalCase`, providers
   `camelCase` ending in `Provider`. One widget per file.
2. **State**: Riverpod. Screen = `ConsumerWidget`/`ConsumerStatefulWidget`.
   Data = `FutureProvider`/`NotifierProvider`. No setState beyond local UI.
3. **Routing**: paths in `app/router.dart`. Screens never `Navigator.push`
   directly — use `context.push('/subject/123')` (go_router). New routes
   MUST be registered in router.dart with their params.
4. **API**: all HTTP through `core/api/api_client.dart`. Endpoint strings
   ONLY in `core/api/api_endpoints.dart` (port from constants/api).
   Auth: `Authorization: Bearer <token>`; token from auth provider.
5. **Models**: plain immutable classes with `fromJson` factories. Shared models in
   `shared/models/` (Subject, User, CollectionItem, Ep, Topic, Blog, Group, Character,
   Person, TimelineItem, CalendarDay...), feature-local models in the feature dir.
   NO build_runner / freezed / json_serializable.
6. **UI text**: Simplified Chinese (original app is zh-CN).
7. **Theme**: `Theme.of(context)`; accent via `AppTheme.accent(context)`.
   Support dark mode via `ThemeMode` in settings.
8. **Images**: `cached_network_image` + `Cover` widget. Always sized.
9. **No dead code**: delete unused imports; `flutter analyze` must pass
   with zero issues before a feature is claimed done.
10. **Tests**: every feature ships at least one widget/unit test in
    `test/features/<name>/`.

## API reference (port of src/constants/api/index.ts)

Base: `https://api.bgmapi.com` (fallback `https://api.bgm.tv`), p1:
`https://next.bgm.tv/p1`.

Key endpoints (see api_endpoints.dart for the complete port):
- GET  /calendar                    — 每日放送
- GET  /search/subject/{kw}         — 条目搜索
- GET  /subject/{id}                — 条目信息
- GET  /subject/{id}/ep             — 章节
- GET  /subject/{id}/characters     — 角色
- GET  /subject/{id}/persons        — 制作人员
- GET  /subject/{id}/relations      — 关联条目
- GET  /subject/{id}/subjects       — 系列
- GET  /subject/{id}/tags           — 条目标签
- GET  /subject/{id}/comments       — 条目吐槽
- GET  /subject/{id}/reviews        — 条目评论
- GET  /subject/{id}/blog           — 条目日志
- POST /collection/{id}/update      — 管理收藏
- GET  /collection/{id}             — 收藏信息
- GET  /user/{uid}/collections      — 用户收藏列表
- GET  /user/{uid}/collections/status
- GET  /user/{uid}/progress         — 收视进度
- GET  /user/{uid}/timeline         — 用户时间线
- GET  /user/{uid}/friends          — 好友
- GET  /user/{uid}/blogs, /user/{uid}/catalogs
- GET  /character/{id}, /person/{id}
- GET  /character/{id}/subjects, /person/{id}/subjects
- GET  /group/{name}, /group/{name}/topics, /group/{name}/members
- GET  /topic/{id}, POST /topic/{id}/new_reply
- GET  /timeline, /timeline/{type}
- GET  /rakuen/board, /rakuen/topics?board=..., /rakuen/group/{name}/topics
- GET  /blog/{id}, POST /blog/{id}/new_reply
- GET  /comment/{id}                — 吐槽箱
- GET  /users/{uid}                 — 用户信息
- GET  /rank/subject?type=&order=&tag=
- GET  /tag/{type}, /tag/{type}/{tag}/subjects
- v0:  /v0/me, /v0/users/{uid}, /v0/users/{uid}/collections?subject_type=&type=&limit=&offset=
- v0:  /v0/users/{uid}/collections/{sid}, /v0/users/-/collections/{sid}/episodes
- p1:  /p1/users/{uid}/timeline?limit=1
- misc: /like, /connect/{uid}, /notify/count, /pm (see api_endpoints.dart)
- tinygrail: /tinygrail/... (see constants/api/tinygrail.ts)

## Screen port matrix (RN screen → Flutter route)

| RN screen | Flutter route | Notes |
|---|---|---|
| screens/discovery/index | /discovery | 发现 tab: grid of entries |
| screens/home/v2 | /progress | Home tab: 收藏进度 (login required) |
| screens/timeline | /timeline | 时间线 tab |
| screens/rakuen/v2 | /rakuen | 超展开 tab |
| screens/user/v2 | /user | 用户 tab |
| screens/tinygrail/index | /tinygrail | 小圣杯 tab (optional) |
| screens/home/subject | /subject/:id | 条目详情 |
| screens/home/info | /subject/:id/info | |
| screens/home/episodes | /subject/:id/episodes | |
| screens/home/characters | /subject/:id/characters | |
| screens/home/persons | /subject/:id/persons | |
| screens/home/rating | /subject/:id/rating | |
| screens/home/preview | /subject/:id/preview | |
| screens/home/mono | /mono/:type/:id | 角色/人物 |
| screens/home/voices | /mono/person/:id/voices | 人物的角色 |

| screens/discovery/calendar | /calendar | 每日放送 |
| screens/discovery/search | /search | |
| screens/discovery/rank | /rank | |
| screens/discovery/anime | /anime | 找番剧 |
| screens/discovery/staff | /staff | 新番 |
| screens/discovery/catalog | /catalog | 目录 |
| screens/discovery/yearbook | /yearbook | 年鉴 |
| screens/discovery/tags | /tags | |
| screens/discovery/blog | /blogs | |
| screens/discovery/group | /groups | |
| screens/discovery/series | /series | 关联系列 |
| screens/discovery/recommend | /recommend | 猜你喜欢 |
| screens/discovery/like | /like | |
| screens/discovery/pic | /pic | |
| screens/discovery/wiki | /wiki | |
| screens/discovery/channel | /channel | 电波提醒 |
| screens/discovery/vib | /vib | 评分月刊 |
| screens/discovery/typerank | /typerank | 分类排行 |
| screens/rakuen/board | /rakuen/board/:key | |
| screens/rakuen/group | /rakuen/group/:name | |
| screens/rakuen/topic | /rakuen/topic/:id | |
| screens/rakuen/blog | /rakuen/blog/:id | |
| screens/rakuen/notify | /rakuen/notify | 电波提醒 |
| screens/rakuen/history | /rakuen/history | |
| screens/rakuen/mine | /rakuen/mine | |
| screens/rakuen/search | /rakuen/search | |
| screens/rakuen/setting | /rakuen/setting | 屏蔽规则 |
| screens/timeline/say | /timeline/say/:id | 吐槽详情 |
| screens/user/zone | /user/:id | 用户空间 |
| screens/user/timeline | /user/:id/timeline | 时光机 |
| screens/user/milestone | /user/:id/milestone | 照片墙 |
| screens/user/blogs | /user/:id/blogs | |
| screens/user/catalogs | /user/:id/catalogs | |
| screens/user/friends | /user/:id/friends | |
| screens/user/pm | /pm | 短信 |
| screens/user/setting | /settings | 设置 |
| screens/user/backup | /settings/backup | 本地备份 |
| screens/user/smb | /settings/smb | 本地文件夹 |
| screens/user/user-setting | /settings/user | |
| screens/user/origin-setting | /settings/origin | |
| screens/user/server-status | /settings/status | |
| screens/login | /login | OAuth webview |
| screens/web-view/web-browser | /web/:url | 内置浏览器 |
| screens/web-view/bilibili-sync | /sync/bilibili | |
| screens/web-view/douban-sync | /sync/douban | |
| screens/web-view/share | /share | 拼图分享 |
| screens/web-view/versions | /versions | |
| tinygrail/* | /tinygrail/* | 小圣杯 submodule |

Every row in this matrix must exist as a route by the end of the rewrite.

## 完成状态 (2026-08-12, v1.0.0)

- 140+ 条路由 + 6 个 Tab, 全部页面已移植 (见上方矩阵, 各 feature 的 routes 文件为准)
- 全部数据源对照线上验证: 官方 v0 API / 主站 HTML 解析 (旧版 JSON API 部分下线,
  与原 App 一致采用 fetchHTML + cheerio 等价方案) / 小圣杯实测 API
- `flutter analyze`: 0 issues; `flutter test`: 122 tests passing
- CI (GitHub Actions) 通过; v1.0.0 Release 含 Android APK/AAB

## 与原版 (czy0729/Bangumi v8.38.2) 功能对齐记录 (2026-08-12)

对照原版 128 个导出页面逐项核对, 本版本新增/对齐:

- **小圣杯-游戏指南** `/tinygrail/wiki` — 原版 11 章本地文本 + Drawer 目录锚点跳转
  (内容提取自原版 wiki/ds.ts, 见 `wiki_data.dart`)
- **小圣杯-资产分析** `/tinygrail/tree` — 角色+圣殿合并矩形树图 (squarify 算法移植自
  原版 utils/thirdParty/treemap.ts, 见 `treemap.dart`); 范围/计算类型切换, 长按隐藏
- **小圣杯-富豪树** `/tinygrail/tree-rich` — 前百首富 treemap, 点击用户跳其资产分析
- **小圣杯-热门榜单** `/tinygrail/overview` — 5 tab: 精炼排行/最高股息/最高市值/
  最大涨幅/最大跌幅 (原 `/tinygrail/rank` 指向同页)
- **小圣杯首页菜单** — 对齐原版 19 项宫格 (热门榜单/番市首富/ICO 榜单/每周萌王/
  英灵殿/最新圣殿/通天塔/我的买单/卖单/拍卖/持仓/资金日志/人物搜索/游戏指南/
  道具 + 本地保留入口), 买单/卖单/拍卖带挂单数徽章
- **发现页** — 顶部 Award 年度评选横幅 (简化静态卡, 跳 `/award/{year}`) + 年鉴入口;
  在线状态行 `online N` (主站 HTML 解析) + 今日上映文案

第七轮对齐 (发现页 / 设置 chrome, 2026-08-14):

- **发现菜单图标** — 对齐原版 `MENU_MAP` (`equalizer` / `live_tv` / `calendar_today` / `local_play` / `folder+favorite` 叠层等), 圆底白标。
- **发现 dashboard** — 右侧改主站 `今日上映 N 部，共 M 人收看`; 去掉「今日放送」分区标题。
- **今日放送** — 对齐原版 `todayBangumi`: 过滤未知 `2359`, 按当前时刻取前 10 + 后 1 再反转, 第 3 格出 `now`。开关只控制今日横滑, 不影响类型轨。
- **发现分区轨** — 主站 `#featuredItems` (动画/游戏/书籍/音乐/三次元), 失败再回退本周 calendar。封面叠关注文案, 音乐 1:1。
- **设置选择器** — 字号/字距/菜单列数/图片质量/首页排序等改 `BgmSelect`; 主题模式/站龄/条目区块改 `BgmSegmented`。`lib/` 已无 `DropdownButton` / `SegmentedButton`。
- **维基人 / 评分筛选** — 分类分段改 `BgmSegmented`。
- **进度顶栏** — 电波改信封 + 粉点 (原版 IconNotify); 有未读短信进收件箱 tab。自定义入口复用 `BgmMenuMark` 叠层。
- **我的右侧** — `image-aspect-ratio` 进照片墙 (原版 Milestone), 不再进时光机。
- **时间线范围** — 左上 48x24 粉底药丸改 `BgmSelect`, 叠在 42pt 页签行, 对齐原版 TabBarLeft。
- **超展开更多** — 横点 `md-more-horiz`; 预读改独立下载钮, 主菜单只留搜索/设置/发帖。
- **小圣杯首页** — 去掉标题栏; Auth 行头像/会员/切主题/刮刮乐菜单; 资产条点按缩略; 2 列大菜单块右叠图标, 对齐 MENU_ITEMS; 底栏改文字链。
- **条目更多** — 对齐原版 MENU_DS: 浏览器查看/复制链接/复制分享/拼图分享/网页分享/设置; 子页面入口只留位置按钮。
- **时间线行** — 「不看 TA」改横点, 对齐原版 Header 更多。
- **进度源头** — 对齐原版 BtnOrigin: 置顶 / 全部展开 / 全部收起 / 一键添加提醒 / 导出 ICS。
- **更多图标** — HeaderV2Popover 默认 `md-more-horiz`; 排行/我的/空间/超展开行不再用竖点。
- **发现年度大赏** — 固定 2025 终端 / 2024 海报 / 2023 复古窗, 右滑出年鉴。
- **发现 2025 终端** — 打字 90ms / 停顿 25×200ms, 对齐原版 award-2025。
- **排行筛选** — 对齐原版 ToolBar: 灰底圆角、无下拉箭头。
- **搜索栏** — 对齐原版连体: 左分类 / 中输入 / 右细度, 无下拉箭头。
- **我的排序** — 对齐原版 ToolBar.Popover, 无下拉箭头。
- **搜索繁简** — 设置 `s2t` 开启后顶栏显示「简/繁」, 输入走原版 cn-char `t2s`。
- **每日放送筛选** — 对齐原版 ToolBar.Popover, 清除改关闭钮。
- **标签 / 索引** — 顶栏更多改横点, 浏览器查看进菜单; 分类排行吃打包快照 ID。
- **每日放送筛选项** — 从当周条目标签动态抽出改编/标签/制作并计数; ON_AIR 打包数据不搬。
- **登录底栏** — 注册先确认再外开, 带外开图标, 对齐原版 Footer。
- **条目吐槽筛选** — 对齐原版 SectionTitle 右侧: 版本/收藏状态/分数/倒序, 选中出粉字; 倒序从总页-1 向前翻。
- **年鉴页** — 对齐原版: 2022 横幅 + 2018-2021 图块 + 2010-2017 两列方格。
- **年鉴详情** — 年份由路由决定, 顶栏不再放年选菜单; 浏览器查看进横点菜单。
- **图集** — 类型筛进顶栏 `filter_list`, 去掉底下横条; 选中粉标。
- **AI 推荐** — 对齐原版搜索行: 左幽灵分类 / 中用户 ID / 右查询。
- **目录工具栏** — 对齐原版 ToolBar.Popover: 整合/热门/最新药丸, 整合才出类型/年份/关键字, 右侧搜索进目录搜索。
- **猜你喜欢** — 类型改全宽 `BgmSegmented`, 对齐原版 SegmentedControl。
- **年鉴加载** — 对齐原版 Loading: 「网页加载中」+ 浏览器打开。
- **猜你喜欢设置** — 对齐原版 ActionSheet: 说明/用户 ID/显示已收藏/10 维 likeRec。
- **全站日志** — 类型改粉下划线 `BgmTabStrip`; 浏览器查看进横点菜单。
- **维基人** — 默认入库; 分类全宽分段; 浏览器查看进横点菜单。
- **关联系列** — 刷新仍确认; 说明进横点菜单。
- **小组 / 我的小组** — 浏览器查看进横点菜单。
- **顶栏地球图标** — 原版 HeaderV2Popover 页统一 `BgmHeaderMore`; 找番剧/漫画/游戏 Extra 是切布局+回顶。
- **条目信息 / 关联** — 原版无浏览器入口; 关联 Extra 是齿轮设置抽屉, 标题带数量。
- **分类排行** — 原版无浏览器入口, 只留说明 / 标签跳转。
- **目录详情** — 顶栏头像+标题 (视觉长度 14 起 12pt); 复制并创建目录 / 浏览器查看 / 网页版查看进横点; 布局/倒序进工具栏。条目收录目录进原生 `/catalog/:id`。
- **好友** — 浏览器查看和说明进横点菜单, 对齐原版 DATA; 我的好友长按头像: 发短信/解除好友, 反向: 移除对我的关注; 顶栏时钟批量拉 p1 活跃度并按一小时/一天/三天…分组。
- **新番** — 顶栏只留浏览器查看; 切季走页面筛选, 不对齐左右箭头。
- **Dollars** — 标题 `ONLINE：N`; 刷新叠 AUTO/OFF; 编辑切输入; 去掉重复在线行。
- **业界资讯** — 来源 + 浏览器查看只走横点菜单, 去掉页面内分段。
- **VIB 月刊** — 正文只显示当期; 小组讨论和月份进横点; 底下左右切上下期。
- **帖子聚合** — 说明进横点菜单, 对齐原版 DATA。
- **社区项目** — 点标题进项目, 点右侧讨论/小组进对应帖或组。
- **半月刊** — 小组讨论和浏览器查看进横点菜单。
- **频道** — 类型 + 浏览器查看只走横点, 去掉页面内 TypeTabs。
- **短信详情** — 分线才出回全部; 相关会话和浏览器查看进横点。
- **索引** — 类型/年/月/排序走工具栏; 顶栏横点: 布局/收藏/浏览器查看。
- **排行榜** — 顶栏改公共横点, 文案对齐原版 布局/加载/收藏; 浏览器地址走当前筛选。
- **搜索 / 标签** — 顶栏更多改公共横点; 标签类型改粉下划线页签。
- **全站日志 / 维基 / 小组** — 顶栏更多改公共横点, 只留浏览器查看。
- **每日放送** — 顶栏菜单文案对齐原版 布局/收藏/未知时间番剧 + 补充说明。
- **目录** — 浏览器查看 + 补充说明进公共横点, 人像钮仍进我的目录。
- **关联系列 / AI 推荐** — 说明 (推荐另有帖子讨论) 进公共横点。
- **超展开** — 顶栏更多改公共横点: 小组搜索 / 超展开设置 / 添加新讨论。
- **帖子 / 日志** — 顶栏更多改公共横点, 帖子带 id 行 + 复制/分享/举报。
- **小组详情** — 加入/退出和时间格式进横点; 论坛行可切最近/日期。
- **我的小组** — 顶栏更多改公共横点, 只留浏览器查看。
- **分类排行** — 标题带类型和标签; 去掉底下 TypeTabs; 书签回标签页。
- **本地管理** — 顶栏改公共横点, 只留新增服务。
- **条目更多** — 公共横点, 文案对齐原版 MENU_DS, 补跳转管理进自定义跳转。
- **小圣杯道具** — 道具说明进公共横点。
- **我的菜单** — DATA_ME 对齐原版, 不含本地管理/备份/设置。
- **时光机工具栏** — 更多改公共横点, 文案对齐 布局/分页器/年份。
- **空间更多** — 公共横点, 文案对齐原版 MENU_DS。
- **超展开板块** — 顶栏更多只留浏览器查看。
- **好友** — 顶栏说明改补充说明; 我的好友不再套双层脚手架。
- **时间线** — 标题 `{用户名}的时间线`, 说明仍是进度瓷砖延迟。
- **设置** — 顶栏只留 Status 波形, 点开 Bangumi Status 设置层; 正文不再重复可用性开关。
- **自定义源头** — 说明进公共横点。
- **网络探针** — 标题对齐原版, 全部检测移到底部。
- **自定义跳转** — 顶栏只留说明, 添加沉到正文底部。
- **个人设置** — 顶栏还原/保存对齐原版 Check, 展开资料走主站 /settings。
- **日志** — 书签弹出 favor, 浏览器查看仍在横点。
- **人物** — 浏览器查看进公共横点。
- **支持者 / 本地备份** — 说明进公共横点。
- **关于客户端** — 原版 qiafan 标题, 不再叫我的卡片。
- **照片墙** — 筛选条 + 设置层对齐原版 Filter/Options。
- **短信详情** — Extra 标题 `全部/线程名 (条数)`、长标题缩小、回全部/上下线程与新主题。

- **关于客户端** — 正文对齐原版说明, 不再用签名卡。
- **支持者** — 顶栏图表/列表切换 + 说明。
- **空间** — tabs 对齐原版 关于/收藏/统计/时间线/超展开/小圣杯; 收藏 tab 改状态分组封面概览, 底部查看全部收藏。

- **人物** — 标签改虚拟角色/现实人物。
- **目录独立页** — 创建的/收藏的挂在 AppBar。
- **超展开** — 帖子/日志/小组/我的/搜索/电波/聚合/用户协议顶栏与正文 Extra 对齐。
- **进度/时间线** — 吐槽 Extra 标题动作, 时间线补好友范围, 进度游客 Auth 与源头菜单。
- **条目独立页** — Extra `{name}的…` 标题与区块名对齐原版。
- **发现** — 找漫画/文库/条目/番剧标题; 年鉴去掉发明顶栏; 找条目频道条对齐原版 FilterSwitch。
- **小圣杯** — Extra 榜单/委托/持仓/资产重组等标题与 IconGo。
- **时光机** — 工具栏补标签 (主站 #userTagList) 与分页器; 列表走 HTML 整页 tag/order; 照片墙补标签筛选。
- **用户评分** — Extra 顶栏「所有/好友」对齐原版 Filter。
- **条目标签 / 吐槽** — Extra `{name}的标签` / `{name}的吐槽`。
- **目录详情 / 好友** — Extra 顶栏头像标题与网页版查看; 条目收录目录进原生详情; 我的好友长按菜单对齐 DATA_FRIEND / DATA_REV_FRIEND。
- **用户标签 / 词云** — Extra 标题 `{typeCn} · {tag}` 与 equalizer 进分类排行; 词云 `{name}的词云`。
- **排行榜 / 索引** — Extra 工具栏锁定/浮动; 排行补分页器锁定与分页加载。
- **好友** — Extra 顶部药丸按用户名/ID 过滤。
- **章节吐槽 / 概览 / 声优** — Extra 标题 `epN.名` / `{name}的概览` / `{name}的声优 (N)`。
- **影评 / 人物** — Extra `{name}的影评`; 人物浏览器近况走 `/mono/update`, 其余走 `/user/{id}/mono`; Extra 标题我的/TA的人物; 近况可跳到今天分割线。

- **Dollars** — Extra 标题 `ONLINE：N` / `DOLLARS`; 输入收起且下滑两屏才出回顶。
- **分类排行** — Extra 书签进 `/tags/{type}/{tag}`。
- **我的小组** — Extra 顶栏「我的/全部」; 全部走主站小组列表, 不移植打包 JSON 筛选。
- **关联系列** — Extra 工具栏锁定/浮动 + 排序/年/类型/状态筛选。
- **目录** — Extra 工具栏/分页器可锁定或浮动。
- **人物角色** — Extra `{name}的角色 (N)` + 外层/内层排序与职位筛选; 人物详情补最近演出角色。
- **日志 / 新番 / 索引 / 排行 / 日历 / 目录 / 标签** — Extra 顶栏补网页版查看。
- **作品** — Extra 排序 名称/日期/排名 + 主站职位筛选。
- **搜索联想 / 分类排行 / 贴贴 / Dollars AUTO** — 打包标题联想与人物联想; 分类排行吃 `typerank/*-ids` 快照条数 `(N)` 与「优于%」; 贴贴改表情网格; Dollars AUTO 持久化且 4 秒轮询。
- **用户标签** — Extra 工具栏排序/年/月/公共标签走主站 `/{type}/tag/{tag}/airtime`；标签索引可按关键字搜 `/search/tag`。
- **目录详情 / 日志** — Extra 工具栏排序/布局/收藏范围/倒序; 留言 (N/5+) 与 TA 的其他目录; 类型条动画/角色/人物/小组/章节/日志; 日志顶栏收藏星与「吐槽 N」。
- **制作人员 / 好友时钟** — Extra 职位筛选（全部职位 (N) + 动画制作排前）；好友顶栏时钟批量拉 p1 `timeline?limit=1`，按一小时/一天/三天…分组。
- **人物收藏 / 概览** — Extra 顶栏收藏星走主站 `collectUrl` / `eraseCollectUrl`；概览工具栏按本篇/Disc 计数筛选。
- **电波提醒 / 自定义跳转** — Extra 连续相同提醒合并 `xN`; 自定义跳转标题吃条目名。















































- **登录** — 新增 Token 登录模式 (粘贴 access_token, 校验失败自动回滚, 原版 login/token)
- **文库** `/wenku` — 与漫画 `/manga` 同页 (标题区分), 主站书籍浏览页等价实现

第二轮对齐 (页面内部功能, 2026-08-12):

- **条目详情页** — 章节长按菜单 (标记看过/撤销/看到第 N 话/本集讨论, 原版 doEpsSelect);
  收藏区改 5 状态按钮组 (想看/在看/看过/搁置/抛弃, 点击直接切换) + 人数分布行 +
  管理弹窗入口 (原版 box)
- **帖子详情页** — 楼层长按菜单: 回复/贴贴 (POST /like type=8)/复制文本/复制链接/
  屏蔽用户/绝交 (原版楼层操作菜单)
- **电波提醒页** — 双 tab (提醒/收件箱, 收件箱复用 PM 列表); 进入页面自动清除全部
  未读 (GET /json/notify → notify_ignore_url, 原版 doClearNotify)
- **用户空间页** — 他人右上角 10 项菜单: 浏览器查看/复制链接/复制分享文案/发短信/
  TA的收藏/TA的好友/谁加TA为好友/加为好友/绝交/报告疑虑 (原版 zone menu);
  好友页支持反向好友 tab (`/user/:id/friends?rev=1`, 原版 type: 'rev');
  用户页加 Netaba 数据入口
- **我的 (超展开)** — 新增"我的小组"tab (抓 /group/mine 主站 HTML, 原版 rakuen/mine);
  修复发现页菜单 照片墙/时间线 死链 (新增 /my-milestone、/my-timeline 路由)

第三轮对齐 (页面内部功能, 2026-08-13):

- **小圣杯列表工具栏** — 富豪榜 `1-100 / 周股息 / 流动资产` (API extra=0/1);
  资金日志按描述分 全部/刮刮乐/ICO/卖出/买入/圣殿/拍卖/魔法/分红;
- **首页进度行** — 对齐原版 tool-bar: 源头 / +1 (书籍 Chap+1 Vol+1) / 收藏管理;
  长按弹批量进度; 点话数展开章节网格 (点击切换看过, 长按进讨论);
  源头含内置站点 + 自定义, `[CN]/[JP]/[ID]` 替换
- **条目详情** — 主站 HTML 解析锁定横幅 (`div.tipIntro`)、猜你喜欢 (`ul.coversSmall`)
  与用户动态/谁在看 (`#subjectPanelCollect`); 收藏区旁加源头按钮。
  游戏详情块仍依赖第三方数据集, 未移植

第四轮对齐 (2026-08-13):

- **条目曲目** — 音乐条目解析 `ul.line_list_music` 碟片/曲目, 点击进章节讨论
- **首页宫格** — 封面底部进度条 + `N / 总集数` (游戏显示收藏状态)
- **条目单行本 / 书籍进度** — `h2.subtitle=单行本` 横向封面; 书籍头 Chap/Vol 输入 +1
- **首页放送** — 进度行标题旁显示今天/明天/周几 + bangumi-data 时刻
- **好友评分 / 在看人数** — `div.frdScore` 显示在条目评分下; 进度行补 `N 人在看/读/玩`
- **首页宫格点选** — 点封面选中, 顶部复用列表行工具栏 (源头/+1/收藏); 长按进条目
- **时间线不看 TA** — 原版 `1/3/7天不看TA`, 本地存到期时间并过滤列表
- **用户空间页签** — 补 统计 (Netaba 网页等价) 与 小圣杯资产摘要 (看持仓树图)
- **超展开二级筛选** — 小组: 全部/已加入/我发表/我回复; 人物: 全部/虚拟/现实。列表 URL 对齐原版 `/rakuen/{scope}?type=`
- **条目词云** — 头部菜单进 `/wordcloud?subjectId=`, 用条目标签词频等价原版 KV 分词
- **自定义放送** — 进度行长按今天/周几, 本地存 weekday+HHMM, 可恢复默认
- **超展开预读** — 更多菜单「预读取未读帖子」, 一次最多 20 条写入浏览历史 (原版 PREFETCH_COUNT)
- **条目自定义放送** — 章节区「放送」按钮, 与进度行共用本地 weekday+HHMM
- **发现页类型横滑** — 本周 calendar 按动画/书籍/游戏/三次元分组 (原版 list-item 等价)
- **章节倒序** — 条目章节区和章节页工具栏对齐原版 `toggleReverseEps`
- **超展开已读** — 浏览过的帖子标题/回复数变淡
- **首页宫格选中即展章节** — 对齐原版 grid/info `Eps`
- **超展开收藏星/坟贴** — 列表黄星 + 90 天未回复标「坟」
- **超展开回复增量** — 已读后新回复显示第二个 `+N`, 日志/旧帖(groupId<440000) 对齐原版 title
- **条目页区块顺序** — 对齐原版 TopEls/BottomEls: Lock/Head/Ep/SMB/Tags/Summary/Thumbs/Info/Rating/Character/Staff/Anitabi/Comic/Relations/Catalog/Like/Blog/Topic/Recent/Comment
- **条目收藏评语** — 管理收藏下展示本人 comment, 点击打开收藏面板
- **条目前传续集** — 标题下最多 2 个关系芯片, 对齐原版 series 前传/续集
- **进度下一话** — 对齐原版 btn-ep-next, 按钮显示下一话 sort
- **超展开头像** — 列表解析 avatarNeue, 点击进空间
- **进度下一集日期** — 对齐原版 getNextInfo, 显示 epN · 日期 / 完结
- **超展开头像协议** — `//lain.bgm.tv` 补 https, 才能加载
- **时间线日期分组** — 列表按天插入今天/昨天/月日, 对齐原版 SectionHeader
- **我的右上角菜单** — 对齐原版 DATA_ME: 空间/好友/反向好友/人物/目录/日志/词云/时光机/Netaba
- **进度季度未看** — 对齐原版 getLeftText: `2026 春 · N 集未看`
- **条目标题长按复制** — 对齐原版「条目.复制标题」, 中日文标题均可复制
- **发现菜单列数** — 对齐原版 discoveryMenuNum, 设置里切 4/5 列, 默认 5
- **进度空状态** — 对齐原版 FOOTER_EMPTY_TEXT; 筛选无结果时「前往搜索」带上关键词
- **条目网页版分享** — 对齐原版 onWebShare, 复制 APP SPA 链接并打开
- **空间 TA的人物** — 对齐原版 zone TEXT_MENU_CHARACTER, `/user/:id/mono`
- **空间发短信** — 对齐原版 PM userId, 无会话时走 compose 页发新短信
- **TA的人物列表** — `/user/:id/mono` 角色/人物双 tab
- **用户备注** — 对齐原版 userRemark, 空间页可编辑, 时间线用户名高亮覆盖
- **空间加入/活跃** — 抓用户主页 HTML, 对齐原版 users.join / recent
- **空间同步率** — 同一 HTML 解析 percent/hobby, 对齐原版 Sync
- **条目信息修订** — 信息区标题旁「修订」, 对齐原版 IconWiki
- **进度列表置顶角** — 对齐原版 is-top, 封面左上角点击取消置顶
- **时光机删除** — 解析 a.tml_del, 自己的动态可删, 对齐原版 doDelete
- **帖子小组封面/作者空间** — 解析 a.avatar img.avatar, 点击作者进空间, 对齐原版 GroupInfo/Author
- **章节帖上下集** — 对齐原版 topic/component/top/ep, 替换进相邻 ep 帖
- **时间线删除** — 自己范围解析 tml_del 后主列表可删, 对齐原版 ItemTimeline clearHref
- **吐槽箱状态/评分/版本筛选** — 状态和当前版本走主站 query, 对齐 HTML_SUBJECT_COMMENTS; 分数仍本地筛
- **评分页全部/好友** — 对齐原版 HTML_SUBJECT_RATING + cheerioRating, filter=friends
- **时间线好友/全站 HTML** — 对齐原版 HTML_TIMELINE, 不再走已下线 JSON
- **用户目录创建/收藏页签** — 对齐原版 user/catalogs TABS + HTML_USERS_CATALOGS isCollect
- **短信相关线程** — 对齐原版 RelatedPM, 解析 thread filter 并切换 conversation?thread=
- **用户日志分页** — 对齐原版 fetchBlogs LIMIT=10, /user/{id}/blog?page=
- **用户目录分页** — 对齐原版 fetchCatalogs LIMIT=30, /index[/collect]?page=
- **用户人物分页** — 对齐原版 fetchCharacters/fetchPersons LIMIT=44
- **人物近况** — 对齐原版 /mono/update cheerioRecents, 不再用收藏时间拼列表
- **Dollars 聊天室** — 对齐原版 /dollars cheerioDollars + since_id 轮询 + ajax 发送
- **目录详情收藏/布局/倒序** — 对齐原版 joinUrl/byeUrl + list/grid + reverse
- **小组加入/退出/发帖** — 对齐原版 joinUrl/byeUrl POST join-bye + HTML_NEW_TOPIC
- **主 Tab 标题** - 对齐原版点标题切主题、长按进设置
- **时间线/超展开用户名** - 对齐原版站龄
- **空间头像/站龄** - 对齐原版点击头像进空间、用户名旁站龄
- **条目 NSFW 标签** - 对齐原版条目头 NSFW Tag
- **条目片长/类型/未上映** - 对齐原版 getDuration / titleLabel / showRelease
- **评分隐藏/游戏在玩** - 对齐原版 hideScore 点按显示、进度游戏行 Time
- **条目标题年份/进度季度色** - 对齐原版 title year 与 SEASON_COLORS
- **6 Tab 标题** - 进度/我的/小圣杯也对齐点标题切主题、长按进设置
- **主站 502 / 授权过期提示** - 对齐原版 ErrorNotice / LoginNotice
- **进度章节长按菜单** - 对齐原版 home doEpsSelect: 看过/看到/本集讨论, >24 集确认
- **章节添加提醒** - 对齐原版 getPopoverData 添加提醒, SP/已看不显示
- **进度章节状态色** - 对齐原版 getType: 今天绿 / 已放送 / 未放送灰
- **条目章节状态色** - 对齐原版 getType 今天绿 / 未放送灰
- **章节列表状态色** - 对齐原版 getType 今天绿 / 未放送灰
- **章节菜单共用** - 进度/条目/章节列表共用 doEpsSelect 菜单
- **条目滚动标题 / 服务状态灯** - 对齐原版 HeaderTitle 与 Logo BreathingLight
- **进度标题字号/筛选高亮** - 对齐原版 getVisualLength + getPinYinFilterValue
- **搜索/超展开/收藏标题字号** - 对齐原版 getVisualLength 阈值
- **排行/日历/封面卡标题字号** - 对齐原版 channel/rank visualLength
- **条目头/今日放送封面** - 对齐原版 head 字号阈值与 CoverToday 叠层
- **发现 CoverLg/CoverSm / 进度紧凑隐藏在看** - 对齐原版叠层封面与 homeListCompact
- **发现好友封面 CoverXs** - 对齐原版叠条目名 + 角标头像, 音乐方形、头像左下
- **进度完结番隐藏放送 / 年鉴近年卡** - 对齐原版 OnAir 完结判断与 Award More
- **进度网格放送 / 日历评分时间** - 对齐原版网格 OnAir 与 calendar Rating
- **日历收藏前缀 / 筛选高亮** - 对齐原版 Title collection + Desc 匹配词
- **日历今天现在分割线** - 对齐原版 calendar Line 当前时间插入
- **日历长按收藏** - 对齐原版 ItemLine Manage 打开收藏弹层
- **排行列表/网格收藏** - 对齐原版 ItemSearch Manage
- **搜索条目 Manage / 封面尺寸** - 对齐原版 ItemSearch 收藏与音乐方形
- **列表长按收藏统一入口** - 频道/浏览/推荐/目录共用 showCollectionSheet
- **发现封面/关联列表长按收藏** - 对齐原版 Manage 入口覆盖发现与条目关联
- **日历布局/收藏/未知时间菜单** - 对齐原版 Header 布局切换、只看收藏、未知时间收起与补充说明
- **日历跳到今天 / 排行浏览器** - 对齐原版 calendar IconNavigate 与 rank Header 浏览器查看
- **搜索浏览器查看** - 对齐原版 search Header 打开当前搜索 URL
- **搜索标题高亮 / 频道好友双列** - 对齐原版 ItemSearch Highlight 与 channel Friends
- **频道标题/帖子/日志 / 日历前天 / 标签浏览器** - 对齐原版 channel Header、Discuss 进帖、PREV_DAY_HOUR
- **标签四列网格 / 目录 Header** - 对齐原版 tags Item 网格计数与 catalog 浏览器/我的目录
- **小组原生详情 / 目录主导类型** - 对齐原版小组页入口与 ItemCatalog 最大类型
- **日志类型 URL / 维基新番浏览器** - 对齐原版 HTML_BLOG_LIST 与 Header 浏览器查看
- **年鉴标题 / 我的人物浏览器** - 对齐原版 Bangumi年鉴 与 /mono/update
- **资讯 Header / Dollars ONLINE / 关联系列说明** - 对齐原版业界资讯、ONLINE 与刷新确认
- **推荐/猜你喜欢/VIB/图集 Header** - 对齐原版说明、帖子讨论、小组讨论与类型筛选
- **半月刊/找番剧/找游戏/漫画/索引浏览器** - 对齐原版 Header 浏览器查看
- **词云说明 / 年鉴浏览器 / 目录详情浏览器** - 对齐原版 Information 与浏览器入口
- **条目子页 Header 浏览器** - 对齐原版角色/制作人员/目录/维基/声优/作品/概览/讨论版/评分/章节/标签/吐槽/人物浏览器查看
- **用户/超展开 Header extras** - 对齐原版好友说明、日志/目录浏览器、时光机瓷砖提示、小组/帖子菜单
- **设置 Status / 说明页 / 小圣杯 extras** - 对齐原版 Information、番市首富/持仓/粘贴板标题、高级功能与道具说明
- **备份/跳转/源头/支持者/本地管理/短信 extras** - 对齐原版说明、新增服务、短信导航与每周萌王拍卖入口
- **浏览器/更新内容/特色功能/Webhook extras** - 对齐原版刷新、外部打开与语雀文档入口
- **日志/帖子聚合/影评/吐槽 extras** - 对齐原版浏览器、复制分享、帖子聚合说明与吐槽标题
- **剪贴板预设 / 用户子页链接** - 对齐原版 LinkModal 预设与 /user/{id}/index|blog|mono|friends
- **通天塔/委托/个人设置 extras** - 对齐原版全局持仓切换、批量取消委托与网页保存
- **同步说明 / 角色快捷 extras** - 对齐原版 bilibili/豆瓣 Information 与资产重组右上角入口
- **买入推荐/刮刮乐 extras** - 对齐原版买入推荐算法说明与刮刮乐日榜标题
- **关联系列/DOLLARS extras** - 对齐原版 Information、刷新确认与编辑/自动刷新入口
- **每日放送/目录说明 extras** - 对齐原版 Information 页而非 AlertDialog
- **登录 extras** - 对齐原版注册与隐私保护政策入口
- **条目锚点 / 分类排行 / 词云 / 标准差 extras** - 对齐原版 location 菜单、Information 与偏差度说明
- **我的 Tab 类型条 / 网格 / 分页** - 对齐原版 tab-bar-left、列表/网格切换与 userPagination
- **进度顶栏电波提醒** - 对齐原版 LogoHeader 左侧 IconNotify, 额外入口跟在提醒旁
- **时间线范围选择** - 对齐原版 tab-bar-left, 范围按钮在页签左侧而不是 AppBar leading
- **收藏状态文案按类型** - 对齐原版 $.action: 书籍读 / 游戏玩 / 音乐听, 我的页签与收藏按钮同步替换
- **我的网格年份** - 对齐原版 showYear: 网格封面下显示放送年, 动画显示到月
- **我的页签计数 / 发现频道标题** - 对齐原版 TabBarLabel 数量与 SectionTitle 进频道
- **进度列表筛选** - 对齐原版 Filter: 输入框在列表顶部常驻, 空时显示数量, 不占 AppBar 标题
- **超展开主类型 TabBar** - 对齐原版 RAKUEN_TYPE 顶栏页签, 板块/二级筛选仍在下方

第五轮对齐 (Cookie 排错 + 站点写操作, 2026-08-14):

- **站点 Cookie 检测** — 游客首页也有 `/login` 链接, 旧判定会误报已登录; 现认 `CHOBITS_UID=0`。`normalizeCookieTime` 对齐原版: `=0` 改 2592000, 缺失则补上。
- **章节状态** — `POST /ep/{id}/status/{watched|queue|drop|remove}` (原版 MODEL_EP_STATUS); 长按菜单补「想看 / 抛弃」。
- **收藏管理** — 公开/私密 (`privacy` 0|1) + 吐槽历史 (最多 10 条)。
- **时间线** — Cookie 或 OAuth 均可进; 全站请求 `skipCookies` (原版 `!` 前缀); 「自己」在仅 Cookie 时从 HTML 解用户名。
- **吐槽回复** — `POST /timeline/{id}/new_reply?ajax=1` (formhash + content)。
- **短信新会话** — 可填标题, 空则默认「短信」。

第六轮对齐 (chrome / 登录, 2026-08-14):

- **底栏** — 自绘 `BgmTabBar`: 50pt、无 M3 pill、选中才出字、选中 `colorMain` `#FE8A95`。文案对齐 routesConfig: 发现 / 时间胶囊 / 收藏 / 超展开 / 时光机 / 小圣杯。
- **LogoHeader** — 进度 / 时间胶囊 / 超展开 / 小圣杯 / 未登录时光机 居中 Bangumi 图标 (点按切主题、长按设置)。发现页去掉文字 AppBar。
- **登录** — 主路径账号密码 + 验证码 (`/FollowTheRabbit` → OAuth authorize → access_token)。授权登录 / Token 为次入口。不持久化密码。首页先看板娘预览再进表单, 对齐原版 login/v2 Preview。验证码 GIF 用识图模型自动填 (无 key 则手填)。游客预览依赖原版私有 cookie, 未移植。

- **自有按钮/芯片/弹层** — `BgmButton` (main/plain/ghost, 高 44, 无 M3 涟漪胶囊)、`BgmFilterChip` (粉底选中)、`BgmTabStrip` / `BgmControlledTabStrip` / `BgmDefaultTabStrip` (粉下划线 42pt)、`BgmSheet` / `showBgmSheet` (顶圆角、无 drag handle)、`BgmRetry` (加载失败 + 自有重试)、`BgmSwitch` (绿轨灰关, 对齐 SwitchPro)、`BgmSegmented`、`BgmDialog` / `showBgmConfirm`、`BgmHairline` (0.5pt token 线)。条目头/收藏管理/帖子楼层筛选/设置 Tabs/发现菜单/分页错误页/各页顶栏页签/确认框/超展开列表分割线走这套, 不再用 M3 Chip / FilledButton / AppBar / TabBar / SwitchListTile / SegmentedButton / AlertDialog / Divider。
- **BgmAppBar** — 能 pop 时自动出返回键; `bottom` 可挂 `BgmControlledTabStrip`, 高度计入 preferredSize。
- **Header extras** — 各页右上角「更多」仍用 `PopupMenuButton`, 对齐原版 Header Popover, 不改成 sheet。
- **进度列表行** — 游戏时间在工具栏下; 更新进度或拉章节时标题旁出 Loading; 进度条灰=已放送、粉=已看 (原版 OnairProgress / currentOnAir)。
- **进度筛选 / 空态** — 药丸居中输入叠数量; 空列表和列表底用看板娘 + 随机吐槽 / `- 到底了 -`, 筛选后「前往搜索」。
- **时间线列表行** — 封面靠右、时间在底、「自己」隐藏头像; 回复/贴贴为文字链, 删/不看走 36pt 图标, 不再用 `TextButton.icon`。
- **时间线范围** — 左上 48x24 粉底药丸 Popover (好友/全站/自己); 空列表看板娘 + 吐槽。

- **超展开列表行** — 回复数只在标题 `+N`; 次行 `时间 / 小组 / 用户`; 右侧只留 36pt `BtnPopover` (进入/屏蔽小组或条目/绝交/屏蔽用户)。收藏星叠在标题前。列表应用屏蔽设置。
- **超展开页签** — 小组/人物二级筛叠在页签 popover (原版 TabBarLabel); 去掉板块芯片条; 空列表看板娘。
- **发现分区标题** — 今日放送无「全部」按钮; 类型轨右侧只用 20pt 箭头进频道, 不再用 M3 TextButton / IconButton。
- **我的类型** — 左上 56x24 粉底药丸 Popover; 空列表/登录门看板娘; 加载更多为文字链。
- **M3 收口** — 我的收藏管理走 `showBgmSheet`; 时间线 Cookie 登录和发现菜单重置改为文字链。
- **条目分区标题** — 右侧「更多 + 箭头」(`SectionMore`); 列表底加载更多走 `LoadMoreLink` 文字链。
- **发现菜单宫格** — 深色圆底白图标 + 12pt 粗体字, 4/5 列正方形格, 不再用粉底方块。
- **设置选择器** — 字号/排序/年份/自定义放送改 `BgmSelect` 粉底药丸 Popover, 不再用 M3 DropdownButton。
- **操作钮收口** — 日历清除、搜索查询、Dollars 登录、新吐槽发表改文字链 / `BgmButton`。
- **输入与次级操作** — `BgmField` 对齐原版 Input; 登录/收藏/剪贴板/电波/回帖/短信/Cookie/备份去掉默认描边框和 M3 TextButton。
- **搜索/章节/小圣杯** — 搜索栏走 `BgmField`; 批量更新/全部作品/董事会/献祭/去授权/撤单去掉 M3 Outlined/TextButton。
- **设置列表行** — `BgmSettingRow` 对齐原版 ItemSetting: 左标题、下说明、右控件/箭头, 不再用 M3 ListTile。
- **进度列表行** — 长按改进度走 `BgmField`; 底部季度行左右分栏 + 加粗 10pt, 对齐原版 BottomInfo。
- **超展开设置** — 开关/分段/屏蔽名单/用户协议改 `BgmSettingRow`, 不再用 M3 ListTile / IconButton / InputChip。
- **文字列表行** — `BgmTextRow` 对齐原版讨论/日志行: 标题 +N、下次行、右侧用户时间; 帖子聚合、频道帖子/日志、条目目录/评论/讨论版/巡礼/本地去掉 M3 ListTile。
- **个人设置 / 空间 / Wiki / VIB / 短信** — 设置跳转和资料行改 `BgmSettingRow` / `BgmTextRow`; 登录表单补 `referer=/` 与 `cookietime=0`。
- **源头 / 备份 / 自定义操作 / 服务状态** — 去掉 M3 ListTile, 改自有设置行。
- **操作菜单 / 小圣杯行** — `BgmActionRow` 对齐原版 Popover 操作; 楼层菜单、章节菜单、剪贴板预设、`CharaTile`/`UserTile` 去掉 M3 ListTile。
- **小圣杯列表 / 本地文件夹 / 关于** — 拍卖/圣殿/日志/精炼/搜索/树菜单/关于与版本页改 `BgmTextRow` / `BgmSettingRow`。
- **本地文件夹** — 详情走 `/settings/smb/:id`, 不再 `Navigator.push`。列表分割线改 `BgmHairline`。
- **顶栏图标** — `BgmHeaderAction` 对齐原版 36pt Header 图标; 进度电波/自定义入口、Logo 返回、发现/超展开/条目/小圣杯/我的/WebView 的 AppBar 动作去掉 M3 IconButton。行内 `visualDensity.compact` 加减号仍保留。
- **还原后回潮列表** — 设置/空间/源头/备份/版本/Webhook、超展开聚合、条目预览、目录详情、小圣杯菜单与树图再次去掉 M3 ListTile。
- **剩余顶栏** — 帖子/小组/电波/好友/吐槽/小圣杯/WebView 等 `AppBar` 改 `BgmAppBar`; 行内收藏/进度加减号改 `BgmHeaderAction`。
- **剩余页签 / 筛选** — 业务页 `TabBar` 改 `BgmControlledTabStrip`; 楼层/空间/频道/设置/小圣杯筛选 `ChoiceChip`/`ActionChip`/`Chip` 改 `BgmFilterChip`。`BgmFilterChip.onTap` 可空, 给 PopupMenu 当显示标签。
- **剩余按钮 / 对话框 / FAB** — 重试块改 `BgmRetry`; 主操作改 `BgmButton`; 「全部 / 加载更多 / 清除」改 `BgmTextAction`; 确认框改 `showBgmConfirm` / `showBgmDialog`。帖子收起楼层、自定义操作、SMB 去掉 `FloatingActionButton`。`lib/` 已无 `FilledButton` / `TextButton` / `OutlinedButton` / `AlertDialog`。
- **剩余卡片 / 开关** — 设置/空间/小圣杯/WebView 的 M3 `Card` 改 `BgmCard` 或直接露出 `BgmSettingRow`; 残留 `Switch` 改 `BgmSwitch`。`lib/` 已无 `Card` / `Switch` / `ListTile`。
- **剩余折叠 / 分割线 / 输入** — 条目分区、VIB 月刊、使用技巧改 `BgmExpand`; 列表 `Divider` 改 `BgmHairline`; 业务输入改 `BgmField`。进度筛选 40pt 居中药丸仍自绘 `TextField`。`lib/` 已无 `ExpansionTile`。
- **剩余轻提示** — 复制/保存/失败改 `showBgmToast` (居中暗底 2.4s, 对齐原版 Toast.info)。业务页已无 `SnackBar`。
- **剩余转圈 / 滑条** — 行内加载改 `BgmSpinner`, 全页加载继续走 `Loading`; 评分/进度/词云滑条改 `BgmSlider`。条目进度条和小圣杯深度条仍用 `LinearProgressIndicator`。




























- **条目章节** — 对齐原版 Eps 网格按钮 (点按看过 / 长按菜单), 标题栏倒序/全部/自定义放送去掉 M3 IconButton/TextButton。
- **条目 Head / Box** — 封面叠在圆角卡片上 (`top=_.md+6`); 上映文案叠卡片顶、透明度 0.6; 分数 + `ScoreTag`; 收藏整块拆到 Head 和章节之间。


- **进度宫格选中栏** — 对齐原版 grid/info: 左封面 + 标题/集数/源头, 下方章节网格, 不再复用整行列表项。
- **条目 Box FlipBtn** — 一颗 44/50pt 大状态按钮 (未收藏 / 在看 · 日期 + 右侧评分档位/五星), 点开收藏管理; 收藏变更后延迟 240ms 再 480ms 绕 X 轴翻转 (`perspective=2400`), 对齐原版 FlipBtn。

- **进度宫格 Info 工具栏** — 源头仅动画/三次元; 补下一话 / Chap+Vol / 收藏星, 对齐原版 grid/info/tool-bar。
- **条目模糊背景** — iOS 半屏封面模糊, 非 iOS `AppBar + 160pt` + 浅 scrim, 对齐原版 Bg。

- **FlipBtn 私密** — `CollectionDetail.privacy` 解析 `private`/`privacy`; 私密时按钮出小眼睛。
- **条目 Header** — 未滚动透明叠模糊背景、白字; 滚过 72pt 后实心底 + 紧凑标题, 对齐原版 Header mode=transition / Subject colors。
- **进度宫格选中** — 封面透明度 0.64, 对齐原版 grid item Opacity.active; 不再用粉底描边。
- **进度宫格列数** — 手机竖屏 4、平板 5、手机横屏 9, 间距 10, 对齐原版 `_.isMobileLanscape ? 9 : _.device(4, 5)`。
- **条目 Header 过渡** — 紧凑标题 160ms fade + 上移 24%, 对齐原版 Transition withTiming。
- **条目顶栏底/图标** — `flexibleSpace` + `AnimatedTheme` 160ms 过渡透明/实心与白/黑图标; 浅色吸顶用 `#000`, 未吸顶或暗色用 `#fff`。状态栏随图标亮度切换。
- **进度宫格 Linear** — 暗色下 Info 与网格之间 24pt `surfaceBase` 渐隐, 对齐原版 grid/linear。





















































































































































已知差异 (不可移植 / 等价替代, 有意为之):

| 原版功能 | 本地处理 |
|---|---|
| 圣杯广场 (tinygrail/transaction) | 依赖 czy 私有加密 KV 服务, 无法调用; 未移植 |
| 漫画/文库本地数据集 (protobuf/JSON 打包) | 本地数据集不可移植, 用 bgm.tv 书籍浏览页等价 |
| 辅助登录 (login/assist) | 需硬编码 APP_SECRET + 服务端 OAuth 三连, 价值低; 未移植 |
| 菜单拖拽排序 / Live2D 看板娘 | 本地用设置对话框开关等价; Live2D WebView 未移植 |

| 条目页漫画/文库标签区 | 依赖第三方本地数据集; 未移植 |
| zone 统计图表/关于页签/超展开页签/锐评 | 依赖云端 KV 快照 + AI 服务; 本地用网页版布局等价 |
| 条目页正版播放源/游戏 block/VIB/Anitabi | 依赖 bangumi-data 等第三方数据; 未移植 |
| 条目/帖子云端快照秒开 | 依赖 czy 私有 KV 服务; 本地直连 |
| notify 好友请求同意/忽略按钮 | 旧 JSON /notify 无好友请求类型; 未移植 |
| AI 锐评/翻译 | 依赖外部 AI 服务; 未移植 |
| 我的小组"全部"tab 全量列表 | 依赖本地打包 JSON; 未移植 |
| 封面 CDN 加速 / 评分趋势 / 游戏预览截图 extras | 依赖原版封面镜像鉴权、评分月刊 KV、VNDB/DLsite 第三方图源; 未移植 |
| Android ListenSharedText / Heatmap / Track extras | 依赖原版私有埋点与系统分享接收; 本地已有剪贴板弹窗和拼图分享等价 |
| 每日放送 ON_AIR 改编/制作/标签 | 依赖原版打包 yuc.wiki ON_AIR; 本地从当周条目标签动态抽出 |




## Definition of done (per feature)

- Route registered in router.dart, screen builds without exceptions
- Data loads from real API (no mocks in release code)
- Follows conventions; `flutter analyze` clean; one test file
