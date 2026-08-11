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

- Flutter 3.44.9 stable, Material 3
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

## 完成状态 (2026-08-11, v1.0.0)

- 135 条路由 + 6 个 Tab, 全部页面已移植 (见上方矩阵, 各 feature 的 routes 文件为准)
- 全部数据源对照线上验证: 官方 v0 API / 主站 HTML 解析 (旧版 JSON API 部分下线,
  与原 App 一致采用 fetchHTML + cheerio 等价方案) / 小圣杯实测 API
- `flutter analyze`: 0 issues; `flutter test`: 94 tests passing
- CI (GitHub Actions) 通过; v1.0.0 Release 含 Android APK/AAB

## Definition of done (per feature)

- Route registered in router.dart, screen builds without exceptions
- Data loads from real API (no mocks in release code)
- Follows conventions; `flutter analyze` clean; one test file
