import '../webview/note_screen.dart';

String bilibiliSyncNotePath() {
  return extraNotePath(
    title: 'bilibili 同步',
    message: const [
      '此功能会打开第三方登录页，请自行判断是否使用。',
      '自动对比可能出错，请手动核实后再提交。',
      '网页版没有此功能。',
    ],
    advance: true,
  );
}

String doubanSyncNotePath() {
  return extraNotePath(
    title: '豆瓣同步',
    message: const [
      '此功能目前为实验性质。',
      '请按提示完成数据获取，然后开始同步。',
      '自动对比可能出错，请手动核实后再提交。',
      '网页版没有此功能。',
    ],
    advance: true,
  );
}
