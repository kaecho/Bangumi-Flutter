# Repository Guidelines

Flutter 3.44 rewrite of the Bangumi (bgm.tv) client, ported 1:1 from `czy0729/Bangumi` (v8.38.x). Package `bangumi` (`1.0.4+5`). UI copy is **zh-CN**. Six bottom tabs: 发现 / 时间胶囊 / 收藏 / 超展开 / 时光机 / 小圣杯.



No codegen in `lib/` (no `@freezed` / `@JsonSerializable` / `.g.dart`). `pubspec.yaml` still lists leftover unused `freezed*` / `json_*` / `build_runner` — do not start using them.

Scope / parity decisions: `docs/ARCHITECTURE.md` (RN → Flutter route matrix + intentional non-ports). Day-to-day rules: this file.

## Architecture & Data Flow

Feature-first: `lib/app` → `lib/core` → `lib/features` (8 domains) → `lib/shared` → `lib/design_system`.

```
Screen (ConsumerWidget / ConsumerStatefulWidget)
  → Riverpod (FutureProvider / PagedNotifier / Notifier)
    → ApiClient (Dio)           primary HTTP
    → TinygrailApi              tinygrail.com envelope {State,Value}
    → dart:io _plainGet         third-party URLs (no OAuth header)
      → api_endpoints.dart
        → handwritten Model.fromJson  or  package:html parser
```

```
lib/app/router.dart ── aggregates per-feature *_routes.dart (List<GoRoute>)
lib/core/api/api_client.dart
   ├─ absolute URL (https://…) → used verbatim (buildApiUri)
   ├─ relative path → '$base$path'  (base = host ?? kApiHost)
   ├─ GET fallback: 5xx + host==null → retry once on kApiHostBackup (api.bgm.tv)
   └─ every request attaches Authorization: Bearer + Cookie when present
lib/core/api/api_endpoints.dart ── ONLY place for hosts/URLs (~806 lines)
```

**Data sources** (encoded by helper prefix):

1. Old JSON `apiXxx()` — `https://api.bgmapi.com` (fallback `api.bgm.tv`). Partly dead; do not assume it works.
2. v0 JSON `apiV0Xxx()` — `$kApiV0`. Subject types: 1 book / 2 anime / 3 music / 4 game / 6 real.
3. Main-site HTML `htmlXxx()` + `host: kHost` + `package:html` parsers.
4. Also present: p1 `kApiP1` (`next.bgm.tv/p1`), tinygrail.com, GitHub releases, status host `bgm-status.ry.mk`.

**State** — Riverpod 2.6, no codegen:

- Simple data: `ref.watch(FutureProvider(.family))` + `.when(loading/error/data)`; retry `ref.invalidate`.
- Paged lists: `PagedNotifier<T,A>` / `PagedGridView` / `PagedListView` in `lib/features/discovery/widgets/paged.dart` — implement `fetchPage(arg, page)` (1-based; empty = done). Auto load-more 400px from bottom. Used by discovery list screens (News/Blog/Catalog/Group/Rank/Search/Tags/Browser…). Other features usually use `FutureProvider.family`.
- Settings: `SettingsStore` ChangeNotifier singleton (`settingsStoreProvider`).
- Auth: `AuthController` Notifier.

**Navigation** — go_router only for pages. Never `Navigator.push` a new screen (image viewer in `preview_screen.dart` is the existing exception). `context.push` for detail, `context.go` for tabs. Tabs are standalone `GoRoute`s (no `ShellRoute`) rendered by `TabShell` (`IndexedStack` + `BgmTabBar`). WebView: `'/web/${Uri.encodeComponent(url)}'`.

Default tab from `SettingsStore.initialPage` (`Discovery` / `Timeline` / `Rakuen` / `User` / `Home` → `/progress`). Home + 时光机 always shown; 发现/时间胶囊/超展开 gated by `homeRenderTabs`; 小圣杯 also needs `tinygrailEnabled`. `progressRoutes` is empty — the tab lives only in `TabShell`.

**Theming** — never hand-roll colors/font sizes. `context.ds.*` (`AppThemeData` ThemeExtension): colors `accent` / `star` / `rise` / `fall` / `success` / `error` / `textPrimary|Secondary|Hint` / `surfaceBase|Card` / `border`; type `display` / `title` / `section` / `bodyStrong` / `body` / `label` / `caption` / `meta` / `tiny`. Spacing/radius: `AppGap.*` / `AppRadius.*`. Legacy `AppThemeX` (`context.accent`, `context.bgColor`…) delegates to the same tokens. Default seed `AppPalette.defaultAccent` (`#FE8A95`, 原版 colorMain). Chrome: `LogoHeader` + `BgmTabBar` (选中才出字), 不要用 Material 3 `NavigationBar` 做底栏。


## Key Directories

| Path | Purpose |
|---|---|
| `lib/app/` | `app.dart` (MaterialApp.router), `router.dart`, `tab_shell.dart`, `theme.dart` |
| `lib/core/api/` | `ApiClient` + `buildApiUri` + `apiErrorMessage`; `api_endpoints.dart` |
| `lib/core/auth/` | `AuthController` (`loginWithCode` / `refreshUser` / `canActAsLoggedInProvider`); `SiteCookiesStore` + `formhashProvider` |
| `lib/core/storage/` | `SettingsStore` (`setting_*` prefs); `Cache` (hive_ce untyped boxes) |
| `lib/core/html/` | Shared scrape helpers (`htmlDecode` / `htmlMatch` / relative-time) |
| `lib/core/utils/` | `url_match.dart`, `display.dart` (title length, air date, ICS, NSFW…) |
| `lib/core/status/` | Main-site 502 / auth-expiry / bgm-status notices |
| `lib/core/debug/` | File-backed request log (`DebugLog`) |
| `lib/design_system/` | `tokens.dart`, `colors.dart`, `app_theme_data.dart` (`context.ds`) |
| `lib/shared/` | `widgets/` (Cover, Score, BgmAppBar/BgmPage, BgmHtml, PageStateView…); `models/` (Subject, User, Collection, Ep…) |
| `lib/features/` | discovery, timeline, progress, rakuen, subject, user, tinygrail, webview |
| `widgetbook/` | Design catalog: `flutter run -t widgetbook/main.dart` |
| `test/` | Mirrors `lib/core` + `lib/features` (no `progress/` or `timeline/` dirs) |
| `docs/ARCHITECTURE.md` | Port matrix + 10 mandatory conventions + 已知差异 table |

## Development Commands

```sh
flutter pub get
flutter analyze            # CI: --fatal-infos; must be zero issues
flutter test               # ~201 cases; no mocks/goldens
flutter test --coverage    # CI only; writes gitignored coverage/lcov.info
flutter run                # device + network (bgm.tv)
flutter run -t widgetbook/main.dart
flutter build apk --release --split-per-abi   # Android release only
flutter build appbundle --release
flutter build web          # local compile sanity; not in CI
```

CI (`.github/workflows/ci.yml`, push/PR → `main`): Flutter **3.44.9** stable → `pub get` → `analyze --fatal-infos` → `test --coverage` → upload `coverage/lcov.info` (7 days).

Release (`.github/workflows/release.yml`, tag `v*`): Java 17 + same Flutter pin → analyze + test (no coverage) → split APKs + AAB → GitHub Release body = `CHANGELOG.md` section `## $VERSION`.

No Makefile / melos / scripts/. Plain `flutter` CLI. Flutter SDK on this machine: `~/flutter/bin`.

## Code Conventions & Common Patterns

- **Naming**: files `snake_case.dart`; widgets `PascalCase` (`FooScreen`, shared `Bgm*`); providers `camelCase` ending in `Provider`. One primary widget per file. Endpoint helpers: `api*` / `apiV0*` / `apiP1*` / `html*` / `apiTinygrail*` (+ live `*2`). Hosts `k*`. Settings keys `setting_*`.
- **Formatting**: dart format defaults. Lints: `prefer_single_quotes`, `require_trailing_commas`, `use_key_in_widget_constructors`, `avoid_print`, `unawaited_futures`, `strict-casts` / `strict-inference`. No `print`.
- **Comments**: zh-CN, often `移植自原项目`. Match that.
- **Models**: handwritten immutable class, const ctor + defaults, `factory X.fromJson` with `(json['k'] as num?)?.toInt() ?? 0`. BGM JSON is snake_case; **tinygrail is PascalCase**. `displayName`: Subject `nameCn` > `name`; User `nickname` > `username`. Shared models in `lib/shared/models/`; feature-local otherwise. Never add freezed.
- **Endpoints**: never hardcode hosts/URLs in features. `apiXxx()` returns absolute URLs; relative helpers need `host:` (e.g. `client.get(htmlAward(year), host: kHost)`).
- **API**: default `apiClientProvider`. `get(path, query:, host:)` / `post(...)`. `fetchHtml` = browser-UA scrape. Tinygrail → `TinygrailApi` (unwraps `State==0`). Third-party (bilibili / bangumi-data) → existing `_plainGet` pattern so the OAuth token is not sent. Errors: `apiErrorMessage(e)`; actions → SnackBar; screens → inline retry via `ref.invalidate`.
- **Auth gates**: OAuth **or** site cookie → `canActAsLoggedInProvider`. Cookie writes (PM / 电波 / 点赞 / 加好友) also need `formhashProvider`. Tinygrail login is a **separate** cookie/OAuth on `tinygrail.com`.
- **Screens**: `ConsumerWidget` / `ConsumerStatefulWidget`; rows = Cover + Column(Text); paged discovery → `PagedGridView`/`PagedListView`. Scaffold with `BgmAppBar` + `BgmPage`.
- **Images**: `cached_network_image` via `Cover` / `Avatar`. Always give a size.
- **Do not implement** the 已知差异 rows in `docs/ARCHITECTURE.md` (czy private KV, packed manga/wenku datasets, login/assist APP_SECRET, AI 锐评, Anitabi/VIB game blocks, etc.). Equivalents already exist where intended.
- **Do not invent routes**. Live list is each feature `*_routes.dart`. Matrix in `docs/ARCHITECTURE.md`.

## Important Files

- `lib/main.dart` — `SettingsStore` + `SiteCookiesStore` + `Cache` then `ProviderScope(BangumiApp)`
- `lib/app/router.dart` + `lib/app/app.dart` — routes; `AppTheme.light/dark(seed)` from `themeColorProvider`
- `lib/app/tab_shell.dart` — 6-tab shell + `homeRenderTabs` / `tinygrailEnabled`
- `lib/core/api/api_client.dart` — `buildApiUri` must keep absolute URLs verbatim (commit `d877250`)
- `lib/core/api/api_endpoints.dart` — every URL; old `apiTinygrail*` + live `apiTinygrail*2`
- `lib/core/auth/auth_controller.dart` + `site_cookies.dart`
- `lib/design_system/app_theme_data.dart` — 13 colors + 9 text styles, `context.ds`
- `lib/features/discovery/widgets/paged.dart` — paging contract
- `lib/features/tinygrail/tinygrail_api.dart` — second HTTP client
- `lib/features/user/dev_screen.dart` + `lib/features/webview/versions_screen.dart` — hand-synced `kAppVersion` (must match `pubspec.yaml`)
- `docs/ARCHITECTURE.md` — port matrix + non-port table
- `CHANGELOG.md` + `assets/changelog.md` — keep byte-identical; in-app versions screen loads the asset
- Android launcher color lives only in `android/app/src/main/res/values/ic_launcher_background.xml` (do **not** re-add `values/colors.xml` — duplicate resource broke release `v1.0.3`)

## Runtime/Tooling Preferences

- **Flutter 3.44.9 stable** (CI/release pin), Dart SDK `^3.12.2`. Dev binary: `~/flutter/bin`.
- Package manager: **pub** (`pubspec.lock` tracked). Dependabot weekly for pub + GitHub Actions.
- No codegen step. Hive is untyped `Box<dynamic>` — no `hive_generator`.
- Platforms: Android `com.bangumi.bangumi` minSdk 24 / target 36 (release still signs with **debug** keystore — TODO in `android/app/build.gradle.kts`). iOS bundle `com.bangumi.bangumi`, iOS 13. Web/`linux/` exist as scaffold; **release pipeline is Android-only**.
- Version bump:
  1. `pubspec.yaml` `version:` (`x.y.z+build`)
  2. `## x.y.z - YYYY-MM-DD` in **both** `CHANGELOG.md` and `assets/changelog.md` (`### 新增` / `### 修复`, zh-CN)
  3. `kAppVersion` in `dev_screen.dart` **and** `versions_screen.dart`
  4. `git tag vX.Y.Z` → `release.yml`

## Testing & QA

- **Framework**: `flutter_test` only. No mockito/mocktail, no goldens, no `integration_test/`. Widgetbook is a catalog, not a test runner.
- **Scale**: 17 files, ~201 `test`/`testWidgets` (CI run 2026-08-14: 201 passed). Older “108” / “122” counts in docs are stale — recount rather than hardcode forever.
- **Layout**:

  | Area | File |
  |---|---|
  | core | `api_client_test`, `html_parser_test`, `url_match_test`, `site_cookies_test`, `display_test`, `debug_log_test`, `server_status_test` |
  | features | `subject_models_test`, `user_models_test`, `discovery_models_test`, `catalog_parser_test`, `rakuen_models_test`, `tinygrail_models_test`, `tree_logic_test`, `treemap_test`, `webview_models_test` |
  | leftover name | `test/widget_test.dart` — Subject/Collection **model** tests, not widgets |

  No `test/features/progress/` or `test/features/timeline/` (Say models covered under webview). Only real `testWidgets`: `BgmHtml` in `rakuen_models_test.dart`.

- **Style**: inline HTML/JSON fixtures shaped like live bgm.tv / v0 / tinygrail. No `test/fixtures/`. Every feature needs ≥1 test (`docs/ARCHITECTURE.md`). Nontrivial parser/model change → extend the matching `*_test.dart`. Parsers must stay resilient — bgm.tv HTML is hand-edited.
- **QA gate**: `flutter analyze --fatal-infos` clean + full `flutter test` green before commit.
- **Do not break**:
  - `relativeToEpoch('刚刚')` and `relativeToEpoch('3小时前')` stay **null** (RN parity). `5分钟前` / `2天前` / `3天15时前` still parse.
  - `buildApiUri`: `path.startsWith('http')` → `Uri.parse(path)` verbatim; `host` must not prepend. Absolute example: `apiV0Me()` → `https://api.bgmapi.com/v0/me`.
  - v0 collections `subject_type` is an **integer** enum (`d5646f7`).
  - New HTML browser grids wrap `PagedGridView` via `browser_grid.dart`.
