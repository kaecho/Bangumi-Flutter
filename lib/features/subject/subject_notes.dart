import '../webview/note_screen.dart';

String ratingDeviationNotePath() {
  return extraNotePath(
    title: '标准差',
    message: const [
      '0-1 异口同声',
      '1.15 基本一致',
      '1.3 略有分歧',
      '1.45 莫衷一是',
      '1.6 各执一词',
      '1.75 你死我活',
    ],
  );
}
