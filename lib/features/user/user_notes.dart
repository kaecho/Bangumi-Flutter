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

