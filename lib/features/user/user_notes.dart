import '../webview/note_screen.dart';

String backupNotePath() {
  return extraNotePath(
    title: '本地备份',
    message: const [
      '条目地址和封面地址为可选导出项。',
      '因为这些值长度较长，收藏很多时可能导致导出失败，请自行尝试。',
      '导入收藏因难以维护，目前已不再维护。',
    ],
  );
}

String actionsNotePath() {
  return extraNotePath(
    title: '自定义跳转',
    message: const [
      '目前为实验性。',
      '本功能对应到具体条目，通常用于给单独条目添加特定跳转。',
      '后续会开发云同步和共享功能，请慎重添加带个人信息隐私的链接。',
    ],
  );
}

/// 原版自定义跳转 Header DATA
const kActionsMoreItems = <(String, String)>[('info', '说明')];

/// 原版 Actions Header: params.name || 自定义跳转
String actionsTitle(String? name) {
  final n = name?.trim() ?? '';
  return n.isEmpty ? '自定义跳转' : n;
}

/// 原版赞助 Header DATA
const kSponsorMoreItems = <(String, String)>[('info', '说明')];

/// 原版本地备份 Header DATA
const kBackupMoreItems = <(String, String)>[('info', '说明')];

String originNotePath() {
  return extraNotePath(
    title: '自定义源头',
    message: const ['自定义数据源，供条目页跳转使用。', '链接可使用 [CN] [JP] [ID] 占位，会按当前条目替换。'],
  );
}

/// 原版源头 Header DATA
const kOriginMoreItems = <(String, String)>[('info', '说明')];

String sponsorNotePath() {
  return extraNotePath(
    title: '支持者',
    message: const [
      '图表根据支持额按比例划分。',
      '点击方格隐藏 1 格，若你为支持者长按可进入空间。',
      '除此外还有 50 多个支持者没有留名。',
      '@senken 提供的 100 刀 iOS 开发账号。',
      '@magma 提供的服务器和 OSS 服务。',
      '数据不定期更新，感谢各位的支持。',
    ],
  );
}
