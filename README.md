# Bangumi (Flutter)

一个基于 [Flutter](https://flutter.dev) 的 [Bangumi](https://bgm.tv) 第三方客户端。

本仓库是 [czy0729/Bangumi](https://github.com/czy0729/Bangumi)（React Native 版，v8.38.x）的
**1:1 功能重写版**：原项目所有功能在重写版中一一对应，使用最新稳定版 Flutter（3.44.x，
Material 3）与最新的 Flutter/Dart 特性，面向长期演进与企业级工程实践设计。

## 功能

- 番组进度管理（首页收藏：全部 / 动画 / 书籍 / 三次元 / 游戏）
- 条目详情、角色 / 人物详情、章节进度管理、收藏管理
- 时间线（全部 / 吐槽 / 收藏 / 进度 / 日志 / 人物 / 好友 / 小组 / 维基 / 目录）
- 超展开（全局聚合、新番乐园、小组、帖子、日志、电波提醒、屏蔽规则）
- 每日放送、搜索、排行榜、找条目、新番、目录、年鉴、标签、分类排行、评分月刊
- 用户空间、时光机、照片墙、好友、短信
- 小圣杯（角色交易空气游戏）
- bilibili / 豆瓣同步、内置浏览器、本地备份、本地文件夹管理
- 深色模式、自定义主题色、毛玻璃效果、图片缓存

完整页面清单见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 的页面移植矩阵。

## 技术栈

| 层 | 选型 |
|---|---|
| 框架 | Flutter 3.44.x (stable) + Dart 3.12 |
| UI | Material 3, 自定义主题（浅色/深色/跟随系统 + 8 种主题色） |
| 状态管理 | Riverpod (flutter_riverpod) |
| 路由 | go_router（每个 feature 维护自己的路由表） |
| 网络 | dio（主域名 api.bgmapi.com，失败自动降级 api.bgm.tv） |
| 数据模型 | 手写不可变 model + fromJson（无代码生成依赖） |
| 本地存储 | shared_preferences（设置）+ hive_ce（缓存） |
| 图片 | cached_network_image |

## 开始开发

```bash
# 需要 Flutter 3.44+ (stable)
flutter pub get
flutter analyze
flutter test
flutter run
```

## 工程结构

```
lib/
  app/          # 应用根组件、路由聚合、主题
  core/         # API 客户端、认证、存储、工具
  features/     # 按功能域划分 (discovery/subject/progress/timeline/rakuen/user/tinygrail/webview)
  shared/       # 跨功能共享的模型与组件
```

每个 feature 目录包含自己的 `*_routes.dart`（go_router 路由表）与屏幕代码；
`lib/app/router.dart` 负责聚合所有 feature 路由。

详细约定见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## CI / CD

GitHub Actions：

- `ci.yml` — PR / main 分支：`flutter analyze` + `flutter test`
- `build.yml` — 打 tag 时构建 Android APK / AAB 并上传 GitHub Release

## 免责

- 本项目所有数据信息均来自各种网站，不提供任何形式的媒体下载、直接播放和修改功能
- 本项目承诺不保存任何第三方用户信息
- 本项目代码仅供学习交流，不得用于商业用途

## 致谢

- [czy0729/Bangumi](https://github.com/czy0729/Bangumi) 原项目
- [bangumi/api](https://github.com/bangumi/api) 官方接口
- [bangumi-data](https://github.com/bangumi-data/bangumi-data) 番组数据索引
