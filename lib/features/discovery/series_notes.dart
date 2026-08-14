import '../webview/note_screen.dart';

String seriesNotePath() {
  return extraNotePath(
    title: '关联系列',
    message: const ['用来查漏补缺，找出还没收藏的关联番剧。', '基于在看和看过收藏做关联，收藏越多范围越广。'],
    advance: true,
  );
}
