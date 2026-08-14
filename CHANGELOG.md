# CHANGELOG

## 1.0.3 - 2026-08-14

### 新增

- 应用图标对齐原版娘口三三 (Android 自适应/圆角 + iOS + Web)
- 发现/进度/超展开/空间/小圣杯继续 1:1 对齐原版布局与交互
  - 日历: 今天分割线、只看收藏、布局切换、长按收藏、前天规则
  - 进度: 宫格选中工具栏、章节菜单、放送状态色、下一话日期、季度未看
  - 超展开: 主类型 Tab、已读变淡、回复增量、预读、小组加入/发帖
  - 条目: 区块顺序、曲目、单行本、自定义放送、词云、NSFW/片长标签
  - 时间线: HTML 好友/全站、日期分组、删除动态、不看 TA
  - 空间: 备注、同步率、站龄、人物/目录/日志分页、短信线程
  - 小圣杯: 持仓树图、游戏指南、富豪榜/资金日志筛选
- Dollars 聊天室轮询发送、目录收藏/网格/倒序、Dollars ONLINE

### 修复

- 主站 502 / 授权过期提示 (对齐 ErrorNotice / LoginNotice)
- 头像协议 `//lain.bgm.tv` 补 https
- Release 工作流按版本截取 CHANGELOG 段落
- Android 资源重复: 删除与官方 `ic_launcher_background.xml` 冲突的 `colors.xml`

## 1.0.2 - 2026-08-12

### 新增

- 自建设计系统 (Design System): 间距/圆角/颜色/字阶 token (`AppGap` / `AppRadius` / `AppPalette` / `AppThemeData` ThemeExtension, 经 `context.ds` 访问)
- 全局组件主题: 底部导航 / Chip / 输入框 / 弹窗 / 底部弹窗 / Tab / 列表项, 统一视觉语言
- 默认主题色改为 bgm.tv 品牌粉 (设置中可切回蓝/绿/紫等预设)
- Widgetbook 设计系统目录 (`flutter run -t widgetbook/main.dart`): 颜色 / 字阶 / 间距 / 组件用例, 支持明暗主题切换
- 62 个页面迁移到设计 token, 移除手写字号/颜色散落

### 修复

- 登录失效: API 请求对绝对 URL 重复拼接 host (`api.bgmapi.comhttps//...`), OAuth 换 token 与 `/v0/me` 全部落空 — 修复为绝对路径直接使用, 相对路径才拼接 base

## 1.0.1 - 2026-08-11

### 新增

- 站点 Cookie 登录支持: 全部请求自动附带 bgm.tv Cookie (与原 App 一致)
  - OAuth 登录后自动从 WebView 捕获 Cookie
  - 设置 → 站点 Cookie 登录: 可粘贴浏览器导出的 Cookie (JSON 数组或 header 格式) 并检测登录态
- 吐槽点赞修复: 补全 formhash/楼层/表情参数
- 用户空间加好友功能 (站点操作, 需 Cookie + formhash)
- 短信/电波提醒/帖子回复支持仅 Cookie 登录 (无需 OAuth)

### 修复

- Cookie 认证功能在无 Cookie 时给出明确引导 (OAuth 或 Cookie 配置入口)

## 1.0.0 - 2026-08-11

### 新增

- Flutter 重写版首个版本, 与原项目 (czy0729/Bangumi v8.38.x) 功能 1:1 对应
- 六个主导航 Tab: 发现 / 时间线 / 首页(进度) / 超展开 / 我的 / 小圣杯
- OAuth2 登录、收藏进度管理、条目详情、时间线、超展开、用户空间
- 每日放送、搜索、排行榜、找条目、新番、目录、年鉴、标签等发现页功能
- 小圣杯模块、bilibili/豆瓣同步、本地备份、本地文件夹管理
- Material 3 主题 (浅色/深色/跟随系统 + 自定义主题色)
- GitHub Actions CI (analyze + test) 与 Release 构建
