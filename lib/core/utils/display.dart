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

/// 封面图质量: 把 lain `/pic/cover/{l|m|c|s|g}/` 改成设置档
String applyCoverQuality(String url, String quality) {
  if (url.isEmpty) return url;
  const map = {
    'grid': 'g',
    'small': 's',
    'medium': 'm',
    'common': 'c',
    'large': 'l',
  };
  final letter = map[quality];
  if (letter == null) return url;
  return url.replaceFirstMapped(
    RegExp(r'/pic/cover/[lmcsg]/'),
    (m) => '/pic/cover/$letter/',
  );
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
