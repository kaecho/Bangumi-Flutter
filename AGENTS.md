# Repository Guidelines

## Project Overview

Flutter 3.44 / Material 3 rewrite of the Bangumi (bgm.tv) client, ported 1:1 from the legacy React Native app `czy0729/Bangumi` (v8.38.x). UI text is **zh-CN**. Six bottom tabs: 发现 / 时间线 / 首页(进度) / 超展开 / 我的 / 小圣杯. No codegen anywhere (no freezed / json_annotation / build_runner / .g.dart).

## Architecture & Data Flow

Layout is feature-first: `lib/app` (root) → `lib/core` (infra) → `lib/features` (8 domains) → `lib/shared` → `lib/design_system`.

```
lib/app/router.dart ── aggregates per-feature *_routes.dart (List<GoRoute>)
lib/core/api/api_client.dart (Dio) ── the ONLY HTTP path
   ├─ absolute URL (https://…) → used verbatim (buildApiUri)
   ├─ relative path → '$base$path' where base = host param ?? kApiHost
   ├─ GET fallback: 5xx + host==null → retry once on kApiHostBackup (api.bgm.tv)
   └─ every request auto-attaches Authorization: Bearer + Cookie headers
lib/core/api/api_endpoints.dart ── single source of truth for all endpoints
lib/core/auth ── AuthController (Notifier) + SiteCookiesStore; drives authTokenProvider
lib/core/html/bgm_html_parser.dart ── shared decode/match helpers for scraping
lib/features/<domain> ── screens + providers + models + html parsers + routes
lib/design_system ── tokens; AppTheme builds ThemeData from them; context.ds accessor
```

**Three data sources** (endpoints encode which):
1. Old JSON API `api.bgmapi.com` (fallback `api.bgm.tv`) — `apiXxx()` full URLs
2. v0 JSON API `$kApiV0` — `apiV0Xxx()`
3. Main-site HTML scraping — `htmlXxx()`/relative paths + `host: kHost` + `package:html` parsers (old JSON API is partly dead; do not assume it works)

**State**: Riverpod 2.6 (no codegen). Two idioms dominate:
- Simple data: `ref.watch(FutureProvider(.family))` + `.when(loading/error/data)`, retry via `ref.invalidate`
- Paged lists: `PagedNotifier<T,A>`/`PagedGridView`/`PagedListView` in `lib/features/discovery/widgets/paged.dart` — `fetchPage(A arg, int page)`, built-in loading/error/refresh/auto-load-more (400px from bottom), used by 10+ screens

**Navigation**: go_router only — never `Navigator.push` directly. `context.push('/subject/$id')`, tab switch via `context.go(path)`. Detail routes per feature in `<feature>_routes.dart` (e.g. `lib/features/subject/subject_routes.dart`), aggregated in `lib/app/router.dart`. WebView routes use `'/web/${Uri.encodeComponent(url)}'`.

## Key Directories

| Path | Purpose |
|---|---|
| `lib/app/` | `app.dart` (MaterialApp.router), `router.dart`, `tab_shell.dart` (IndexedStack + NavigationBar), `theme.dart` (AppTheme light/dark + AppThemeX) |
| `lib/core/api/` | `api_client.dart` (ApiClient + buildApiUri + apiErrorMessage + apiClientProvider), `api_endpoints.dart` (~525 lines, all endpoints) |
| `lib/core/auth/` | OAuth (`auth_controller.dart`: AuthController/`loginWithCode`/`refreshUser`/providers incl. `canActAsLoggedInProvider`), `site_cookies.dart` (SiteCookiesStore, `formhashProvider`, cookie-header builders) |
| `lib/core/storage/` | `settings_store.dart` (SettingsStore singleton ChangeNotifier, `setting_*` prefs keys, `settingsStoreProvider`) |
| `lib/core/html/` | `bgm_html_parser.dart` (htmlDecode/htmlMatch/relative-time parsing) |
| `lib/core/utils/` | shared helpers (url matching etc.) |
| `lib/design_system/` | `tokens.dart` (AppGap/AppRadius), `colors.dart` (AppPalette incl. `defaultAccent`, `accentColors`), `app_theme_data.dart` (AppThemeData ThemeExtension + `context.ds`) |
| `lib/shared/` | `widgets/` (Cover/Avatar, Score/Stars/Tag/SectionHeader, Loading/Empty/Skeleton/PageStateView, BgmAppBar/BgmPage, BgmHtml), `models/` (Subject, User, CalendarDay…) |
| `lib/features/` | discovery, timeline, progress, rakuen, subject, user, tinygrail, webview |
| `widgetbook/` | Design-system catalog entry: `flutter run -t widgetbook/main.dart` |
| `test/` | mirror of lib (core/features), plain flutter_test |
| `docs/ARCHITECTURE.md` | port matrix (RN screen → Flutter route, ~70 rows) + mandatory conventions |

## Development Commands

```sh
flutter pub get
flutter analyze            # must be zero issues (--fatal-infos in CI)
flutter test               # 108 tests, no mocking/golden
flutter run                # device required; app needs network for bgm.tv APIs
flutter run -t widgetbook/main.dart   # design system catalog (light/dark via Addons)
flutter build apk --release --split-per-abi   # release builds are Android-only
flutter build web          # sanity-check compile (used during design work)
```

CI (`.github/workflows/ci.yml`): analyze --fatal-infos + test --coverage on push/PR to main. `release.yml`: tag `v*` → APK/AAB + GitHub release, body from CHANGELOG.md.

## Code Conventions & Common Patterns

- **Formatting**: dart format defaults; lints enforce `prefer_single_quotes`, `require_trailing_commas`, `use_key_in_widget_constructors`, `avoid_print`, `unawaited_futures`, plus `strict-casts`/`strict-inference`. No `print` — use debugger or throw.
- **Comments**: zh-CN, often with `移植自原项目` (ported from RN) markers. Match that style.
- **Models**: plain handwritten immutable classes — const constructor with all-default fields, `factory X.fromJson` with defensive casts `(json['k'] as num?)?.toInt() ?? 0`, snake_case JSON keys (tinygrail is PascalCase), `displayName` getter (nameCn > name). Never add freezed.
- **Endpoints**: every URL goes through `api_endpoints.dart` — never hardcode hosts/URLs in features. `apiXxx()` returns full absolute URLs; relative-path helpers require callers to pass `host:` to the client (e.g. `client.get(htmlAward(year), host: kHost)`).
- **API calls**: only via `apiClientProvider` (`ApiClient`). Use `get(path, query:, host:)` / `post(path, data:, host:)`. `fetchHtml(url)` = browser-UA scraping. Errors surface via `apiErrorMessage(e)`; action failures → SnackBar; screen-level failures → inline retry via `ref.invalidate`.
- **Theming**: NEVER hand-roll colors/font sizes. Use `context.ds.*` (design tokens) — semantic colors (`accent`, `star`, `rise`, `fall`, `success`, `textPrimary/Secondary/Hint`, `surfaceBase/Card`, `border`) and type scale (`display`/`title`/`section`/`bodyStrong`/`body`/`label`/`caption`/`meta`/`tiny`). Spacing/radius via `AppGap.*` / `AppRadius.*`. Existing `AppThemeX` getters (`context.accent`, `context.bgColor`…) delegate to the same tokens.
- **Auth gates**: OAuth OR site-cookie can satisfy login — check `canActAsLoggedInProvider` for cookie-capable features (PM/电波/点赞/加好友 need `formhashProvider` + Cookie header).
- **Navigation**: go_router only; `context.push` for detail, `context.go` for tabs. `BgmAppBar` + `BgmPage` for screen scaffolding.
- **Screens**: ConsumerWidget/ConsumerStatefulWidget; list rows = Cover + Column(Text) layout; paged screens use `PagedGridView`/`PagedListView` with an `AsyncNotifierProvider.family`.

## Important Files

- `lib/main.dart` — entry; async-inits SettingsStore + SiteCookiesStore + Cache before `runApp(ProviderScope(BangumiApp))`
- `lib/app/router.dart` + `lib/app/app.dart` — routing + theme wiring (`AppTheme.light/dark(seed)` from `themeColorProvider`)
- `lib/core/api/api_client.dart` — the only HTTP path; `buildApiUri` must stay correct (absolute URLs used verbatim — see commit d877250)
- `lib/core/api/api_endpoints.dart` — every endpoint; two generations of tinygrail helpers coexist (old `apiTinygrail*` + new `apiTinygrail*2`)
- `lib/core/auth/auth_controller.dart` + `site_cookies.dart` — authentication
- `lib/design_system/app_theme_data.dart` — `AppThemeData` (13 colors + 9 text styles), `context.ds`
- `lib/features/discovery/widgets/paged.dart` — paging contract
- `docs/ARCHITECTURE.md` — port matrix + the 10 mandatory conventions (authoritative for scope decisions)

## Runtime/Tooling Preferences

- **Flutter 3.44.9 stable (pinned in CI)**, Dart SDK `^3.12.2`. Flutter binary at `~/flutter/bin` on dev machine; add to PATH.
- **No codegen**, no melos, no scripts/ or Makefile. Plain `flutter` CLI.
- Package manager: pub (pubspec.lock tracked).
- Platforms: Android (appId `com.bangumi.bangumi`, minSdk 24 / targetSdk 36, release signing still uses debug keystore — TODO in build.gradle.kts) and iOS (bundle id `com.bangumi.bangumi`, deployment target 13.0). Web exists but is untouched scaffold. Release pipeline is Android-only.
- Version bumps: `pubspec.yaml` `version:` + `CHANGELOG.md` entry (`## x.y.z - YYYY-MM-DD`, sections `### 新增` / `### 修复`, zh-CN) + git tag `vX.Y.Z` (tag triggers release.yml).

## Testing & QA

- **Framework**: `flutter_test` only. 108 tests, ~1.5k lines. No mocking libs, no goldens — tests parse inline HTML/JSON fixtures against real bgm.tv markup shapes.
- **Layout**: `test/core/` (html_parser 13, url_match 14, site_cookies 9, api_client buildApiUri 5), `test/features/<domain>_models_test.dart` (subject 16, user 11, tinygrail 10, rakuen 12 incl. 2 `testWidgets` on BgmHtml, discovery 7, webview 7), `test/widget_test.dart` (misnomer — model tests).
- **Convention**: ≥1 test per feature (docs/ARCHITECTURE.md mandate); every nontrivial parser/model change should extend the matching `*_test.dart` with a real-shape fixture. Parsers must stay resilient: bgm.tv HTML is hand-edited by admins.
- **QA gate**: `flutter analyze` zero issues + full suite green before commit. CI runs both with coverage upload (`test --coverage`, artifact kept 7 days).
- **Gotchas**: relative-time parser intentionally returns null for '刚刚'/'3小时前' (RN parity, tested); `browser_grid.dart` wraps PagedGridView for HTML browser pages — keep the pattern when adding discovery screens.
