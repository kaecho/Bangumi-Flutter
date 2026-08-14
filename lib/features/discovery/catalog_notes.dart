import '../webview/note_screen.dart';

String catalogNotePath() {
  return extraNotePath(
    title: '目录整合',
    message: const [
      '整合内容均为作者提前对热门目录的前一千页，进行了清洗无意义垃圾内容、提取标题关键字、类型分类合并等操作后得到的结果。',
      '默认仅支持菜单里的关键字，若想自定义关键字，可到公共搜索页面后，选择目录类型输入关键字点击搜索再进入本页面。',
    ],
  );
}
