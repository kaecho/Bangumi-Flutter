import '../webview/note_screen.dart';

String calendarNotePath() {
  return extraNotePath(
    title: '每日放送数据',
    message: const [
      '客户端内每日放送数据是由多方数据整合而成的。',
      '1：官方每日放送 API 作为当季放送原始列表项。',
      '2：从 bangumi-data 库中获取放送具体时间，若该番剧并没有具体时间，会默认收起以免长期占据显示位置，需要你自行展开列表。',
      '3：标签和动画制作数据摘取自 https://yuc.wiki。',
    ],
  );
}
