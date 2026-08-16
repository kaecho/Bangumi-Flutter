import 'dart:convert';

import 'dart:io';

import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/settings_store.dart';

/// 原项目 `URL_DEFAULT_AVATAR`
const kDefaultAvatarMarker = '/icon.jpg';

/// 原版超展开 18x 关键字 + 条目标题常见敏感词
const kSensitiveKeywords = [
  'gal',
  '性',
  '癖',
  '里番',
  'r18',
  '18禁',
  '18+',
  'hentai',
  'nsfw',
  '成人向',
  '成年',
  'エロ',
];

/// 原项目 `cnFirst`: 开 = 中文优先, 关 = 原名优先
String cnjp(String name, String nameCn, {bool? cnFirst}) {
  final first = cnFirst ?? SettingsStore.instance.cnFirst;
  if (first) return nameCn.isNotEmpty ? nameCn : name;
  return name.isNotEmpty ? name : nameCn;
}

/// 原项目 getVisualLength: 全角/CJK 计 2, 半角计 1
int getVisualLength(String text) {
  var length = 0;
  for (final rune in text.runes) {
    length += rune > 0x7f ? 2 : 1;
  }
  return length;
}

/// 原项目进度标题字号: >28 → 12, >18 → 13, 否则 15
double homeTitleFontSize(String text) {
  final length = getVisualLength(text);
  if (length > 28) return 12;
  if (length > 18) return 13;
  return 15;
}

/// 原项目 PAD_LEVEL_1（Android 528）+ 短边 600 的平板判定
bool isPadLayout(Size size) {
  final minSide = size.shortestSide;
  final maxSide = size.longestSide;
  return minSide >= 600 || (minSide >= 528 && maxSide <= minSide * 1.6);
}

/// 原项目 `_.isMobileLanscape`: 非平板且横屏
bool isMobileLandscape(Size size) =>
    !isPadLayout(size) && size.width > size.height;

/// 原项目宫格列数: `_.isMobileLanscape ? 9 : _.device(4, 5)`
int homeGridNumColumns(Size size) {
  if (isMobileLandscape(size)) return 9;
  return isPadLayout(size) ? 5 : 4;
}

/// 原项目 Header colors.Subject: `_.isDark || !fixed ? '#fff' : '#000'`
Color subjectHeaderForeground({required bool fixed, required bool dark}) {
  return (!fixed || dark) ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
}

/// 原项目 RATING_MAP / getRating: 1-10 分中文档位
const kCollectionRatingLabels = <int, String>{
  1: '不忍直视',
  2: '很差',
  3: '差',
  4: '较差',
  5: '不过不失',
  6: '还行',
  7: '推荐',
  8: '力荐',
  9: '神作',
  10: '超神作',
};

String collectionRatingLabel(num score) {
  if (score <= 0) return '';
  final key = (score + 0.5).floor().clamp(1, 10);
  return kCollectionRatingLabels[key] ?? '不忍直视';
}

/// 原项目 RATIO: 手机 1, 小平板 1.28, 大平板 1.44
double deviceCoverRatio(Size size) {
  if (!isPadLayout(size)) return 1;
  return size.shortestSide >= 880 ? 1.44 : 1.28;
}

/// 原项目 IMG_WIDTH / IMG_HEIGHT (高 = 宽 * 1.4)
int imgWidth(Size size) => (deviceCoverRatio(size) * 82).floor();

int imgHeight(Size size) => (imgWidth(size) * 1.4).floor();

/// 原项目 IMG_WIDTH_LG
int imgWidthLg(Size size) => (imgWidth(size) * 1.34).floor();

/// 原项目进度列表封面: 常规 IMG_WIDTH×IMG_HEIGHT, compact 正方形 IMG_WIDTH-8
({double width, double height}) homeListCoverSize(
  Size size, {
  required bool compact,
}) {
  final w = imgWidth(size);
  if (compact) {
    final side = (w - 8).toDouble();
    return (width: side, height: side);
  }
  return (width: w.toDouble(), height: imgHeight(size).toDouble());
}

/// 原项目条目 Head 封面: `(IMG_WIDTH_LG+16)*1.2`, 音乐正方形且不超过半屏
({double width, double height}) subjectHeadCoverSize(
  Size size, {
  required bool music,
}) {
  final ratio = isPadLayout(size) ? 1.4 : 1.2;
  final large = imgWidthLg(size);
  if (music) {
    final raw = (large * ratio * 1.4).floorToDouble();
    final side = raw > size.width / 2 ? (size.width / 2).floorToDouble() : raw;
    return (width: side, height: side);
  }
  final w = ((large + 16) * ratio).floorToDouble();
  return (width: w, height: (w * 1.4).floorToDouble());
}

/// 原项目 Head 主标题: 视觉长度档 + (大平板 +4 / 其余 +2)
double subjectHeadTitleSize(
  String text, {
  required Size size,
  bool music = false,
  bool hasRelation = false,
}) {
  final bump = size.shortestSide >= 880 ? 4 : 2;
  var value =
      visualFontSize(text, const [
        (44, 10),
        (32, 11),
        (24, 12),
        (16, 12),
        (0, 15),
      ]) +
      bump;
  if (hasRelation) value = value < 13 ? 11 : value - 2;
  if (music) value -= 1;
  return value;
}

/// 原项目 WEEK_DAY_MAP: 0/7=日, 1=一...6=六
String weekdayShort(int weekday) {
  const marks = ['日', '一', '二', '三', '四', '五', '六'];
  if (weekday == 7) return '日';
  if (weekday < 0) return '';
  return marks[weekday % 7];
}

/// 原项目 Meta: `N 人在读/玩/看` + 未开 homeOnAir 时追加 ` · 周X`
String homeDoingMetaText({
  required int doing,
  required String type,
  int weekday = 0,
  bool onAir = false,
  bool homeOnAir = false,
}) {
  if (doing <= 0) return '';
  final verb = type == 'book'
      ? '读'
      : type == 'game'
      ? '玩'
      : '看';
  final text = '$doing 人在$verb';
  if (!homeOnAir && onAir && weekday >= 0) {
    final mark = weekdayShort(weekday);
    if (mark.isNotEmpty) return '$text · 周$mark';
  }
  return text;
}

const kSeasonLabels = ['冬', '春', '夏', '秋'];

/// 原项目 calcSeason: 分界日前 10 天归入下季
({int year, int quarter}) calcHomeSeason(String airDate) {
  final parsed = DateTime.tryParse(airDate);
  if (parsed == null) return (year: 0, quarter: 1);
  var year = parsed.year;
  var adj = parsed.month;
  if (parsed.day >= 22 && parsed.month % 3 == 0) adj = parsed.month + 1;
  if (adj > 12) {
    adj -= 12;
    year += 1;
  }
  return (year: year, quarter: (adj / 3).ceil());
}

/// 原项目 getLeftText: `2026 春 · N 集未看` / 行内用两位年
String homeLeftText({
  required int seasonYear,
  required int quarter,
  required int airedUnwatched,
  required String type,
  bool hasNewEp = true,
  bool sink = false,
  bool twoDigitYear = false,
}) {
  if (seasonYear <= 0) return '';
  final year = twoDigitYear ? seasonYear % 100 : seasonYear;
  final isAnime = type == 'anime';
  final q = quarter.clamp(1, 4);
  var text = isAnime ? '$year ${kSeasonLabels[q - 1]}' : '$year';
  if (airedUnwatched > 0) text += ' · $airedUnwatched 集未看';
  if (isAnime && sink && !hasNewEp) text += ' · 已下沉';
  return text;
}

/// 原项目 getNextInfo: `epN · YY-MM-DD` / 行内空格分隔 / 无下一集=完结
String homeNextInfo({
  required List<({int sort, String airdate})> eps,
  DateTime? now,
  bool showSplit = true,
}) {
  if (eps.isEmpty) return '';
  final today = now ?? DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  ({int sort, String airdate})? next;
  for (final ep in eps) {
    if (ep.airdate.isEmpty) continue;
    final parsed = DateTime.tryParse(ep.airdate);
    if (parsed == null) continue;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (day.isAfter(todayDay)) {
      next = ep;
      break;
    }
  }
  if (next == null) return '完结';
  final date = next.airdate.length >= 10
      ? next.airdate.substring(2)
      : next.airdate;
  final parsed = DateTime.tryParse(next.airdate);
  final days = parsed == null
      ? 0
      : DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
        ).difference(todayDay).inDays;
  final split = showSplit ? ' · ' : ' ';
  var info = 'ep${next.sort}$split$date';
  if (days > 0) info += ' ($days 天后)';
  return info;
}

/// 行内 Meta: 人数 + 季度未看 + 下话
String joinHomeMeta(String doing, {String left = '', String next = ''}) {
  final extras = [left, next].where((e) => e.isNotEmpty);
  if (doing.isEmpty) return extras.join(' · ');
  if (extras.isEmpty) return doing;
  return '$doing · ${extras.join(' · ')}';
}

/// 原项目 OnairProgress: 已看 / 已放送 / 分母
({double watched, double aired}) onairProgressRatios({
  required int watched,
  required int aired,
  required int total,
  int defaultTotal = 12,
}) {
  final denom = (total > 0 ? total : defaultTotal).toDouble();
  double ratio(int value) {
    if (value <= 0) return 0;
    return (value / denom).clamp(0.0, 1.0);
  }

  var watchedRatio = ratio(watched);
  var airedRatio = ratio(aired);
  if (watched > 0 && watchedRatio < 0.02) watchedRatio = 0.02;
  if (aired > 0 && airedRatio < 0.02) airedRatio = 0.02;
  return (watched: watchedRatio, aired: airedRatio);
}

/// 原项目 getCurrentOnAir: 倒序找最后一集已放送 sort; 第 0 集则 +1
int currentOnAir({
  required List<({int type, int sort, String status, String airdate})> eps,
  DateTime? now,
}) {
  final regular = [
    for (final ep in eps)
      if (ep.type == 0) ep,
  ];
  if (regular.isEmpty) return 0;
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  ({int type, int sort, String status, String airdate})? last;
  for (final ep in regular.reversed) {
    if (_epIsAired(ep.status, ep.airdate, day)) {
      last = ep;
      break;
    }
  }
  if (last == null) return 0;
  final zeroBased = regular.first.sort == 0;
  return zeroBased && last.sort > 0 ? last.sort + 1 : last.sort;
}

/// 已放送本篇数 (多季番 current > total 时的原版回退)
int airedRegularCount({
  required List<({int type, int sort, String status, String airdate})> eps,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  var count = 0;
  for (final ep in eps) {
    if (ep.type != 0) continue;
    if (_epIsAired(ep.status, ep.airdate, day)) count++;
  }
  return count;
}

bool _epIsAired(String status, String airdate, DateTime day) {
  if (status == 'Air') return true;
  if (status == 'Today' || status == 'NA') return false;

  if (airdate.isEmpty) return false;
  final parsed = DateTime.tryParse(airdate);
  if (parsed == null) return false;
  final air = DateTime(parsed.year, parsed.month, parsed.day);
  return !air.isAfter(day);
}

/// 原项目 Progress: current 与 total 取较大值作分母
({int aired, int total}) onairProgressCounts({
  required int aired,
  required int total,
}) {
  return (aired: aired, total: aired > total ? aired : total);
}

/// 原项目 FlipBtn 高度: `_.device(44, 50)`
double flipCollectBtnHeight(Size size) => isPadLayout(size) ? 50 : 44;

/// 原项目 getSize(getVisualLength): 按阈值降字号, steps 从大到小
double visualFontSize(String text, List<(int minLen, double size)> steps) {
  final length = getVisualLength(text);
  for (final (minLen, size) in steps) {
    if (length >= minLen) return size;
  }
  return steps.isEmpty ? 14 : steps.last.$2;
}

/// 原项目 getPinYinFilterValue 可移植近似: 返回命中的原文子串
String? pinYinFilterValue(String text, String filter) {
  final needle = filter.trim();
  if (needle.isEmpty || text.isEmpty) return null;
  final index = text.toLowerCase().indexOf(needle.toLowerCase());
  if (index < 0) return null;
  return text.substring(index, index + needle.length);
}

/// 原项目 `URL_DEFAULT_AVATAR` (`/icon.jpg`)
bool isDefaultAvatar(String url) => url.contains(kDefaultAvatarMarker);

/// 原项目 `x18` / `x18s` 的可移植近似: 官方 nsfw 标记 + 标题/小组关键字
bool isSensitiveText(String text) {
  if (text.isEmpty) return false;
  final blob = text.toLowerCase();
  return kSensitiveKeywords.any(blob.contains);
}

bool isSensitiveSubject({
  bool nsfw = false,
  String name = '',
  String nameCn = '',
  String extra = '',
}) {
  if (nsfw) return true;
  return isSensitiveText('$name $nameCn $extra');
}

/// 封面图质量: 统一成 lain `/r/{size}/pic/cover/l/` (原项目 getCover400)
///
/// v0 / 主站新图是 `/r/400/pic/cover/l/`. 旧逻辑把中间的 `l` 改成 `m`,
/// CDN 会 400: please use `/r/{n}/pic/cover/l/` path instead.

String applyCoverQuality(String url, String quality, {double? displayWidth}) {
  if (url.isEmpty) return url;
  var src = url.trim();
  if (src.startsWith('"') || src.startsWith("'")) {
    src = src.substring(1);
  }
  if (src.endsWith('"') || src.endsWith("'")) {
    src = src.substring(0, src.length - 1);
  }
  if (src.startsWith('//')) src = 'https:$src';
  if (src.startsWith('http://')) {
    src = src.replaceFirst('http://', 'https://');
  }
  if (!src.contains('lain.bgm.tv') || !src.contains('/pic/cover/')) {
    return src;
  }

  var size = coverQualityPixelSize(quality);
  final tile = coverTilePixelSize(displayWidth);
  if (tile > size) size = tile;

  src = src.replaceFirst(
    RegExp(r'/r/\d+(?:x\d+)?/pic/cover/[lmcsg]/'),
    '/pic/cover/l/',
  );
  return src.replaceFirst(
    RegExp(r'/pic/cover/[lmcsg]/'),
    '/r/$size/pic/cover/l/',
  );
}

/// 设置档对应的 lain r 边长
int coverQualityPixelSize(String quality) => switch (quality) {
  'grid' => 100,
  'small' => 200,
  'medium' => 400,
  'common' => 400,
  'large' => 800,
  _ => 400,
};

/// 按控件宽度 (约 2x) 决定最小边长, 对齐原项目 getCover400
///
/// `double.infinity` / NaN 不当成超大图, 避免网格/hero Cover 全升到 r/800。
int coverTilePixelSize(double? width) {
  if (width == null || !width.isFinite || width <= 0) return 0;
  final need = width * 2;
  if (need <= 100) return 100;
  if (need <= 200) return 200;
  if (need <= 400) return 400;
  if (need <= 600) return 600;
  return 800;
}

/// 原项目章节热力图透明度: (comment - min/1.68) / max
double heatMapOpacity(int comment, {required int min, required int max}) {
  if (comment <= 0 || max <= 0) return 0;
  final value = (comment - min / 1.68) / max;
  if (value.isNaN || value.isInfinite) return 0;
  return value.clamp(0.08, 1);
}

/// 原项目 getType: 看过 / 今天 / 已放送 / 未放送
String epAirKind(String airdate, {required bool watched, DateTime? now}) {
  if (watched) return 'watched';
  if (airdate.isEmpty) return 'na';
  final parsed = DateTime.tryParse(airdate);
  if (parsed == null) return 'na';
  final today = now ?? DateTime.now();
  final air = DateTime(parsed.year, parsed.month, parsed.day);
  final day = DateTime(today.year, today.month, today.day);
  if (air == day) return 'today';
  if (air.isBefore(day)) return 'air';
  return 'na';
}

/// 首页章节窗口 (原项目 getVisibleEps / homeEpStartAtLastWathed)
List<T> visibleHomeEps<T>(
  List<T> eps, {
  required bool Function(T ep) isWatched,
  bool startAtLast = true,
  int maxLength = 24,
}) {
  if (eps.length <= maxLength) return eps;
  var lastWatched = -1;
  var firstUnwatched = -1;
  for (var i = 0; i < eps.length; i++) {
    if (isWatched(eps[i])) {
      lastWatched = i;
    } else if (firstUnwatched < 0) {
      firstUnwatched = i;
    }
  }
  if (firstUnwatched < 0) {
    return eps.sublist(eps.length - maxLength);
  }
  if (startAtLast) {
    final start = lastWatched < 0 ? 0 : lastWatched;
    return eps.sublist(start, (start + maxLength).clamp(0, eps.length));
  }
  final start = (firstUnwatched - maxLength + 1).clamp(0, eps.length);
  final end = (firstUnwatched + maxLength - 1).clamp(0, eps.length);
  return eps.sublist(start, end);
}

/// 原项目 homeCountView: A=当前/总数 B=当前 (总数) C=总数 (当前) D=当前 / 总数
String homeCountText({
  required int current,
  required int total,
  String style = 'A',
}) {
  if (total <= 0) return '看到第 $current 话';
  return switch (style) {
    'B' => current == total ? '$current' : '$current ($total)',
    'C' => current == total ? '$total' : '$total ($current)',
    'D' => current == total ? '$current' : '$current / $total',
    _ => '$current / $total',
  };
}

/// 原项目 homeSortSink: 没有未看的已放送章节则下沉
bool shouldSinkHomeItem({
  required int watched,
  required int aired,
  bool pinned = false,
}) {
  if (pinned) return false;
  return aired > 0 && watched >= aired;
}

/// 首页排序权重: 越小越靠前。onair=今天>明天>其他; default=当季优先
int homeSortWeight(
  DateTime airDate, {
  required int weekday,
  required String mode,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final todayWd = today.weekday % 7;
  final wd = weekday % 7;
  final isToday = wd == todayWd && weekday > 0;
  final isTomorrow = wd == (todayWd + 1) % 7 && weekday > 0;
  if (mode == 'onair') {
    if (isToday) return 0;
    if (isTomorrow) return 1;
    return 8;
  }
  if (mode == 'default') {
    final seasonStart = DateTime(today.year, ((today.month - 1) ~/ 3) * 3 + 1);
    if (!airDate.isBefore(seasonStart)) return isToday ? 0 : 1;
    return isToday ? 2 : 4;
  }
  return 0;
}

/// 发布日期: 关=年, 开=年-月 (原项目 subjectShowAirdayMonth)
String formatSubjectAirDate(String airDate, {required bool showMonth}) {
  final m = RegExp(r'^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?').firstMatch(airDate);
  if (m == null) return airDate;
  if (!showMonth) return m.group(1)!;
  final month = m.group(2);
  return month == null ? m.group(1)! : '${m.group(1)}-$month';
}

/// 别名提前: 把「别名」挪到「中文名」后 (原项目 subjectPromoteAlias)
List<T> promoteAliasRows<T>(
  List<T> rows, {
  required String Function(T item) keyOf,
}) {
  final alias = <T>[];
  final rest = <T>[];
  for (final row in rows) {
    if (keyOf(row).contains('别名')) {
      alias.add(row);
    } else {
      rest.add(row);
    }
  }
  if (alias.isEmpty) return rows;
  alias.sort((a, b) => keyOf(a).length.compareTo(keyOf(b).length));
  final chinese = rest.indexWhere((e) => keyOf(e).contains('中文名'));
  if (chinese < 0) return [...alias, ...rest];
  return [
    ...rest.sublist(0, chinese + 1),
    ...alias,
    ...rest.sublist(chinese + 1),
  ];
}

/// 原项目 getAge 可移植近似: 数字 uid 越大越新, 1 ≈ 2008-07
double? estimateUserAgeYears(String userId, {DateTime? now}) {
  final id = int.tryParse(userId);
  if (id == null || id <= 0) return null;
  final today = now ?? DateTime.now();
  final start = DateTime.utc(2008, 7, 14);
  // 经验拟合: 早期用户约 4 万/年, 新号更密
  final yearsFromStart = id / 42000;
  final registered = start.add(
    Duration(days: (yearsFromStart * 365.25).round()),
  );
  if (registered.isAfter(today)) return 0;
  final days = today.difference(registered).inDays;
  return days / 365.25;
}

/// 原项目 UserAge 文案
String? userAgeLabel(String userId, {String type = 'year', DateTime? now}) {
  final age = estimateUserAgeYears(userId, now: now);
  if (age == null) return null;
  if (age <= 0) return '最近';
  if (type == 'month' && age < 1) {
    final months = (age * 12).floor();
    return months <= 0 ? '最近' : '$months月';
  }
  final shown = age < 10 ? age.toStringAsFixed(1) : age.floor().toString();
  return '$shown年';
}

/// 原项目 spacing: 中文与半形英文/数字/符号之间插空
String applySpacing(String text) {
  if (text.isEmpty) return text;
  return text
      .replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff])([A-Za-z0-9])'),
        (m) => '${m.group(1)} ${m.group(2)}',
      )
      .replaceAllMapped(
        RegExp(r'([A-Za-z0-9])([\u4e00-\u9fff])'),
        (m) => '${m.group(1)} ${m.group(2)}',
      );
}

String displayText(String text, {bool? spacing}) {
  final on = spacing ?? SettingsStore.instance.spacing;
  return on ? applySpacing(text) : text;
}

Future<void> openExternalUrl(String url) async {
  if (url.isEmpty) return;
  if (SettingsStore.instance.openInfo) {
    await Clipboard.setData(ClipboardData(text: url));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

String _icsStamp(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';
}

/// 生成放送日程 ICS (原项目 genICSCalenderEventDate 简化版)
String buildSubjectIcs({
  required int subjectId,
  required String title,
  required List<({int id, int sort, String name, String airdate})> eps,
  String clock = '2000',
}) {
  final hour =
      int.tryParse(clock.substring(0, clock.length >= 2 ? 2 : 0)) ?? 20;
  final minute = clock.length >= 4
      ? int.tryParse(clock.substring(2, 4)) ?? 0
      : 0;
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'PRODID:-//Bangumi//Anime Calendar//CN',
    'VERSION:2.0',
    'METHOD:PUBLISH',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:Bangumi放送日程',
  ];
  for (final ep in eps) {
    final parsed = DateTime.tryParse(ep.airdate);
    if (parsed == null) continue;
    final start = DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
    final end = start.add(const Duration(minutes: 30));
    final desc =
        'https://bgm.tv/ep/${ep.id}${ep.name.isEmpty ? '' : ' (${ep.name})'}';
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:$subjectId-${ep.id}',
      'TZID:Asia/Shanghai',
      'DTSTART:${_icsStamp(start)}',
      'DTEND:${_icsStamp(end)}',
      'SUMMARY:$title ep.${ep.sort}',
      'DESCRIPTION:$desc',
      'TRANSP:OPAQUE',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

Future<void> shareSubjectIcs({
  required int subjectId,
  required String title,
  required List<({int id, int sort, String name, String airdate})> eps,
  String clock = '2000',
}) async {
  final body = buildSubjectIcs(
    subjectId: subjectId,
    title: title,
    eps: eps,
    clock: clock,
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/bangumi_$subjectId.ics');
  await file.writeAsString(body);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

/// 原项目 getPopoverData.canAddCalendar: 未看且非 SP, 且放送日未过
bool canAddEpCalendar({
  required int type,
  required String airdate,
  required bool watched,
  DateTime? now,
}) {
  if (watched || type != 0 || airdate.isEmpty) return false;
  final parsed = DateTime.tryParse(airdate);
  if (parsed == null) return false;
  final today = now ?? DateTime.now();
  final air = DateTime(parsed.year, parsed.month, parsed.day);
  final cutoff = DateTime(today.year, today.month, today.day);
  return !air.isBefore(cutoff);
}

String buildWeekOnAirIcs(
  List<({int id, String title, String airdate, String clock})> items,
) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'PRODID:-//Bangumi//Anime Calendar//CN',
    'VERSION:2.0',
    'METHOD:PUBLISH',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:Bangumi每日放送',
  ];
  for (final item in items) {
    final parsed = DateTime.tryParse(item.airdate);
    if (parsed == null) continue;
    final clock = item.clock.length >= 4 ? item.clock : '2000';
    final hour = int.tryParse(clock.substring(0, 2)) ?? 20;
    final minute = int.tryParse(clock.substring(2, 4)) ?? 0;
    final start = DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
    final end = start.add(const Duration(minutes: 30));
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:week-${item.id}-${item.airdate}',
      'TZID:Asia/Shanghai',
      'DTSTART:${_icsStamp(start)}',
      'DTEND:${_icsStamp(end)}',
      'SUMMARY:${item.title}',
      'DESCRIPTION:https://bgm.tv/subject/${item.id}',
      'TRANSP:OPAQUE',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

Future<void> shareWeekOnAirIcs(
  List<({int id, String title, String airdate, String clock})> items,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/bangumi_week.ics');
  await file.writeAsString(buildWeekOnAirIcs(items));
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

String _infoboxJoined(List<({String key, String value})> rows) {
  return rows.map((e) => '${e.key}: ${e.value}').join('\n');
}

/// 原项目 parseMusicDuration: 327 分 / 146m / 186:49 / 72:27+65:45
String parseMusicDuration(String rawInfo) {
  if (!rawInfo.contains('播放时长')) return '';
  final m1 = RegExp(r'(\d+)\s*(分|m)').firstMatch(rawInfo);
  if (m1 != null) return '${int.parse(m1.group(1)!)} min';

  int toMinutes(String s) {
    final parts = s.split(':').map(int.tryParse).toList();
    if (parts.any((n) => n == null)) return 0;
    if (parts.length == 3) return parts[0]! * 60 + parts[1]!;
    if (parts.length == 2) return parts[0]!;
    return 0;
  }

  final m2 = RegExp(r'播放时长[\s\S]*?(\d+:\d+(?:\+\d+:\d+)+)').firstMatch(rawInfo);
  if (m2 != null) {
    final total = m2
        .group(1)!
        .split('+')
        .fold<int>(0, (sum, part) => sum + toMinutes(part.trim()));
    return total > 0 ? '$total min' : '';
  }
  final m3 = RegExp(r'播放时长[\s\S]*?(\d+:\d+(?::\d+)?)').firstMatch(rawInfo);
  if (m3 != null) {
    final minutes = toMinutes(m3.group(1)!);
    return minutes > 0 ? '$minutes min' : '';
  }
  return '';
}

/// 原项目 parseMaxDurationFromEps: 章节 H:MM:SS 最大分钟
int parseMaxDurationFromEps(Iterable<String> durations) {
  var maxSeconds = 0;
  for (final item in durations) {
    final parts = item.split(':').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((n) => n == null)) continue;
    final seconds = parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    if (seconds > maxSeconds) maxSeconds = seconds;
  }
  return (maxSeconds / 60).ceil();
}

/// 原项目 parseMovieDuration: 片长 120 分钟
int parseMovieDuration(String rawInfo) {
  final match = RegExp(r'片长[\s\S]*?(\d+)\s*(分钟|分)').firstMatch(rawInfo);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// 原项目 getDuration: 仅剧场版/电影显示片长
String subjectMovieDuration({
  required String titleLabel,
  required Iterable<String> epDurations,
  required String rawInfo,
}) {
  if (titleLabel != '剧场版' && titleLabel != 'MOVIE' && titleLabel != '电影') {
    return '';
  }
  final fromEps = parseMaxDurationFromEps(epDurations);
  if (fromEps > 26) return '$fromEps min';
  final fromInfo = parseMovieDuration(rawInfo);
  if (fromInfo > 26) return '$fromInfo min';
  return '';
}

/// 原项目 titleLabel 可移植近似: 动画用 tags/类型 infobox, 其余用类型文案
String subjectTitleLabel({
  required String typeText,
  required List<({String key, String value})> infobox,
  required List<String> tags,
}) {
  if (typeText == '动画') {
    for (final row in infobox) {
      if (row.key.contains('类型') && row.value.isNotEmpty) {
        final first = row.value.split(RegExp(r'[\/,，]')).first.trim();
        if (first.isNotEmpty) return first;
      }
    }
    for (final tag in tags) {
      if (tag == '剧场版' || tag == '电影' || tag.toUpperCase() == 'MOVIE') {
        return tag == 'MOVIE' ? 'MOVIE' : tag;
      }
    }
    return typeText;
  }
  for (final row in infobox) {
    if ((row.key == '类型' || row.key == '作品种类') && row.value.isNotEmpty) {
      return row.value.split(RegExp(r'[\/,，]')).first.trim();
    }
  }
  return typeText;
}

/// 原项目 showRelease: 年月日齐全且未到, 或只有年/年月
bool subjectShowRelease(String release, {DateTime? now}) {
  if (release.isEmpty) return false;
  final hasYear = release.contains('年') || RegExp(r'^\d{4}').hasMatch(release);
  final hasMonth =
      release.contains('月') || RegExp(r'^\d{4}-\d{1,2}').hasMatch(release);
  final hasDay =
      release.contains('日') ||
      RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(release);
  if (hasYear && hasMonth && hasDay) {
    final normalized = release
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-');
    final parts = normalized.split('-').where((e) => e.isNotEmpty).toList();
    if (parts.length < 3) return true;
    final date = DateTime.tryParse(
      '${parts[0].padLeft(4, '0')}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}',
    );
    if (date == null) return true;
    return date.isAfter(now ?? DateTime.now());
  }
  return hasYear && !hasDay;
}

String subjectReleaseText(List<({String key, String value})> infobox) {
  const keys = ['发售日', '放送开始', '上映年度', '上映时间', '上映日', '发行日期'];
  for (final row in infobox) {
    if (keys.any(row.key.contains) && row.value.isNotEmpty) return row.value;
  }
  return '';
}

String subjectHeaderDuration({
  required String typeText,
  required List<({String key, String value})> infobox,
  required List<String> tags,
  required Iterable<String> epDurations,
}) {
  final raw = _infoboxJoined(infobox);
  final music = parseMusicDuration(raw);
  if (music.isNotEmpty) return music;
  return subjectMovieDuration(
    titleLabel: subjectTitleLabel(
      typeText: typeText,
      infobox: infobox,
      tags: tags,
    ),
    epDurations: epDurations,
    rawInfo: raw,
  );
}

const _kPrimaryDateKeys = ['连载开始', '开始'];
const _kSecondaryDateKeys = [
  '发售日',
  '发售日期',
  '放送开始',
  '上映年度',
  '上映时间',
  '上映日',
  '发行日期',
];

String? extractYear(String text) =>
    RegExp(r'(\d{4})').firstMatch(text)?.group(1);

String? extractYearMonth(String text) =>
    RegExp(r'(\d{4}[-年]\d{1,2})').firstMatch(text)?.group(1);

String normalizeYearMonth(String value) {
  final match = RegExp(r'(\d{4})[-年](\d{1,2})').firstMatch(value);
  if (match == null) return value;
  return '${match.group(1)}-${match.group(2)!.padLeft(2, '0')}';
}

String? _infoboxValue(
  List<({String key, String value})> infobox,
  List<String> keys,
) {
  for (final row in infobox) {
    if (keys.any(row.key.contains) && row.value.isNotEmpty) return row.value;
  }
  return null;
}

/// 原项目 getYear: 连载开始优先, 否则发售/上映
String subjectYear({
  required List<({String key, String value})> infobox,
  String airDate = '',
}) {
  final primary = _infoboxValue(infobox, _kPrimaryDateKeys);
  final fromPrimary = primary == null ? null : extractYear(primary);
  if (fromPrimary != null) return fromPrimary;
  final secondary = _infoboxValue(infobox, _kSecondaryDateKeys);
  final fromSecondary = secondary == null ? null : extractYear(secondary);
  if (fromSecondary != null) return fromSecondary;
  return extractYear(airDate) ?? '';
}

/// 原项目 getYearAndMonth
String subjectYearMonth({
  required List<({String key, String value})> infobox,
  required String year,
}) {
  final primary = _infoboxValue(infobox, _kPrimaryDateKeys);
  final secondary = _infoboxValue(infobox, _kSecondaryDateKeys);
  final raw =
      extractYearMonth(primary ?? '') ?? extractYearMonth(secondary ?? '');
  if (raw == null || raw.isEmpty) return year;
  return normalizeYearMonth(raw);
}

/// 原项目 calendarFlat 时刻: `HHMM` / `HH:MM` → 4 位数字, 非法为 0
int airClockDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 3) return 0;
  return int.tryParse(digits.length >= 4 ? digits.substring(0, 4) : digits) ??
      0;
}

/// 原项目 todayBangumi: 当前时刻前 10 条 + 后 1 条, 再反转
///
/// [stamps] 为周几*10000+HHMM (周一=1 … 周日=7)。未知 `2359` 应先过滤。
List<T> todayOnAirWindow<T>({
  required List<T> items,
  required int Function(T item) stampOf,
  DateTime? now,
}) {
  if (items.isEmpty) return const [];
  final clock = now ?? DateTime.now();
  final current = clock.weekday * 10000 + clock.hour * 100 + clock.minute;
  var index = items.indexWhere((item) => current >= stampOf(item));
  if (index < 0) index = 0;
  final len = items.length;
  final result = <T>[];
  for (var i = index - 10; i <= index + 1; i++) {
    result.add(items[((i % len) + len) % len]);
  }
  return result.reversed.toList();
}

String? _scTable;
String? _tcTable;

/// 原项目 cn-char t2s: 繁体转简体
Future<void> loadCnCharTables() async {
  if (_scTable != null && _tcTable != null) return;
  _scTable =
      jsonDecode(await rootBundle.loadString('assets/data/sc.json')) as String;
  _tcTable =
      jsonDecode(await rootBundle.loadString('assets/data/tc.json')) as String;
}

void seedCnCharTables({required String sc, required String tc}) {
  _scTable = sc;
  _tcTable = tc;
}

String t2s(String str) {
  final sc = _scTable;
  final tc = _tcTable;
  if (sc == null || tc == null || sc.isEmpty || tc.isEmpty) return str;
  final out = StringBuffer();
  for (final rune in str.runes) {
    final ch = String.fromCharCode(rune);
    final idx = tc.indexOf(ch);
    out.write(idx == -1 ? ch : sc[idx]);
  }
  return out.toString();
}
