/// 时间格式化工具 (移植原项目 utils/date)
library;

/// 友好相对时间
String friendlyTime(String time, {String? prefix}) {
  if (time.isEmpty) return '';
  final dt = DateTime.tryParse(time.replaceFirst(' ', 'T'));
  if (dt == null) return time;
  return friendlyTimeOf(dt, prefix: prefix);
}

String friendlyTimeOf(DateTime dt, {String? prefix}) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && now.day == dt.day) return '${diff.inHours}小时前';

  if (now.year == dt.year) {
    return '${dt.month}月${dt.day}日';
  }
  return '${dt.year}年${dt.month}月${dt.day}日';
}

/// 绝对时间 (带日期)
String absoluteTime(String time) {
  if (time.isEmpty) return '';
  final dt = DateTime.tryParse(time.replaceFirst(' ', 'T'));
  if (dt == null) return time;
  final now = DateTime.now();
  if (now.year == dt.year) {
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.year}年${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// 星期文案
const List<String> kWeekdayCn = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
const List<String> kWeekdayJa = ['日', '月', '火', '水', '木', '金', '土'];

/// 年龄计算 (时光机等)
int? calcAge(String birthday) {
  final parts = birthday.split('-');
  if (parts.length < 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final now = DateTime.now();
  var age = now.year - year;
  if (now.month < month || (now.month == month && now.day < day)) age--;
  return age;
}

/// HTML 标签去除 (轻量)
String stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

/// 字符串截断
String ellipsis(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}
