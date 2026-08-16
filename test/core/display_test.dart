import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/utils/display.dart';
import 'package:bangumi/shared/models/subject.dart';

import 'package:bangumi/shared/widgets/mesume.dart';
import 'package:bangumi/shared/widgets/mesume_speech.dart';

void main() {
  group('cnjp', () {
    test('中文优先与原名优先', () {
      expect(cnjp('魔法少女まどか☆マギカ', '魔法少女小圆', cnFirst: true), '魔法少女小圆');
      expect(cnjp('魔法少女まどか☆マギカ', '魔法少女小圆', cnFirst: false), '魔法少女まどか☆マギカ');
      expect(cnjp('', '魔法少女小圆', cnFirst: false), '魔法少女小圆');
      expect(cnjp('まどか', '', cnFirst: true), 'まどか');
    });
  });

  group('mesume', () {
    test('话语池非空且随机落在池内', () {
      expect(kMesumeSpeeches.length, 150);
      expect(kMesumeAssets.length, 7);
      final speech = randomMesumeSpeech(Random(1));
      expect(kMesumeSpeeches, contains(speech));
    });
  });

  group('getVisualLength / homeTitleFontSize / pinYinFilterValue', () {
    test('CJK 计 2, 半角计 1, 长标题缩小', () {
      expect(getVisualLength('abc'), 3);
      expect(getVisualLength('魔法少女'), 8);
      expect(homeTitleFontSize('短'), 15);
      expect(homeTitleFontSize('一二三四五六七八九十'), 13);
      expect(homeTitleFontSize('一二三四五六七八九十ABCDEFGHIJ'), 12);
      expect(visualFontSize('一二三四五六七八九十', const [(20, 13), (0, 14)]), 13);
      expect(visualFontSize('短', const [(20, 13), (0, 14)]), 14);
    });

    test('筛选命中返回原文子串', () {
      expect(pinYinFilterValue('魔法少女小圆', '少女'), '少女');
      expect(pinYinFilterValue('Madoka Magica', 'magi'), 'Magi');
      expect(pinYinFilterValue('普通标题', 'xyz'), isNull);
    });
  });

  group('homeListCoverSize / subjectHeadCoverSize / subjectHeadTitleSize', () {
    const phone = Size(390, 844);

    test('进度封面 82x114, compact 正方形 74', () {
      expect(imgWidth(phone), 82);
      expect(imgHeight(phone), 114);
      expect(homeListCoverSize(phone, compact: false), (
        width: 82.0,
        height: 114.0,
      ));
      expect(homeListCoverSize(phone, compact: true), (
        width: 74.0,
        height: 74.0,
      ));
    });

    test('条目 Head 封面按 IMG_WIDTH_LG * 1.2', () {
      final normal = subjectHeadCoverSize(phone, music: false);
      expect(normal.width, 150);
      expect(normal.height, 210);

      final music = subjectHeadCoverSize(phone, music: true);
      expect(music.width, music.height);
      expect(music.width, lessThanOrEqualTo(phone.width / 2));
    });

    test('Head 主标题手机 +2, 音乐再 -1', () {
      expect(subjectHeadTitleSize('短', size: phone), 17);
      expect(subjectHeadTitleSize('短', size: phone, music: true), 16);
    });

    test('getRating 四舍五入到档位', () {
      expect(collectionRatingLabel(7.4), '推荐');
      expect(collectionRatingLabel(7.5), '力荐');
    });
  });

  group('isSensitiveSubject', () {
    test('官方 nsfw 标记与关键字', () {
      expect(isSensitiveSubject(nsfw: true), isTrue);
      expect(isSensitiveSubject(name: '普通动画', nameCn: '普通动画'), isFalse);
      expect(isSensitiveSubject(nameCn: '里番合集'), isTrue);
      expect(isSensitiveSubject(extra: 'R18 galgame'), isTrue);
    });
  });

  group('isDefaultAvatar / applyCoverQuality', () {
    test('识别空头像并改封面档位', () {
      expect(
        isDefaultAvatar('https://lain.bgm.tv/pic/user/l/icon.jpg'),
        isTrue,
      );
      expect(
        isDefaultAvatar('https://lain.bgm.tv/pic/user/l/000/12.jpg'),
        isFalse,
      );
      expect(
        applyCoverQuality('https://lain.bgm.tv/pic/cover/l/ab/cd.jpg', 'grid'),
        'https://lain.bgm.tv/r/100/pic/cover/l/ab/cd.jpg',
      );
      expect(
        applyCoverQuality('https://lain.bgm.tv/pic/user/l/icon.jpg', 'small'),
        'https://lain.bgm.tv/pic/user/l/icon.jpg',
      );
    });

    test('v0 /r/400/pic/cover/l 不被改成非法 /m/', () {
      const src =
          'https://lain.bgm.tv/r/400/pic/cover/l/14/a1/545008_pNnzQ.jpg';
      expect(
        applyCoverQuality(src, 'medium'),
        'https://lain.bgm.tv/r/400/pic/cover/l/14/a1/545008_pNnzQ.jpg',
      );
      expect(applyCoverQuality(src, 'medium'), isNot(contains('/cover/m/')));
      expect(
        applyCoverQuality(src, 'large'),
        'https://lain.bgm.tv/r/800/pic/cover/l/14/a1/545008_pNnzQ.jpg',
      );
    });

    test('旧 /pic/cover/c 与 grid 按档位升级到 r/N/l', () {
      expect(
        applyCoverQuality('http://lain.bgm.tv/pic/cover/c/ab/cd.jpg', 'medium'),
        'https://lain.bgm.tv/r/400/pic/cover/l/ab/cd.jpg',
      );
      expect(
        applyCoverQuality(
          '//lain.bgm.tv/r/100/pic/cover/l/ab/cd.jpg',
          'medium',
          displayWidth: 88,
        ),
        'https://lain.bgm.tv/r/400/pic/cover/l/ab/cd.jpg',
      );
      expect(
        applyCoverQuality(
          'https://lain.bgm.tv/r/400/pic/cover/l/ab/cd.jpg',
          'medium',
          displayWidth: double.infinity,
        ),
        'https://lain.bgm.tv/r/400/pic/cover/l/ab/cd.jpg',
      );
    });
  });

  group('Subject.nsfw', () {
    test('解析 v0 nsfw 标记', () {
      expect(Subject.fromJson({'nsfw': true}).nsfw, isTrue);
      expect(Subject.fromJson({}).nsfw, isFalse);
    });
  });

  group('heatMapOpacity', () {
    test('按原版公式缩放并夹取', () {
      expect(heatMapOpacity(0, min: 0, max: 10), 0);
      expect(heatMapOpacity(10, min: 0, max: 10), 1);
      expect(heatMapOpacity(1, min: 0, max: 100) > 0, isTrue);
    });
  });

  group('userAgeLabel', () {
    test('早期数字 uid 显示年, 新号显示最近', () {
      final now = DateTime.utc(2026, 8, 13);
      expect(userAgeLabel('1', now: now), contains('年'));
      expect(userAgeLabel('sai', now: now), isNull);
      expect(
        userAgeLabel('99999999', type: 'month', now: now),
        anyOf('最近', contains('月'), contains('年')),
      );
    });
  });

  group('applySpacing', () {
    test('中文与半形英文数字之间插空', () {
      expect(applySpacing('薬屋のひとりごと第2期'), isNot(contains('第2')));
      expect(applySpacing('第2期'), '第 2 期');
      expect(applySpacing('24话'), '24 话');
    });
  });

  group('visibleHomeEps', () {
    test('长篇从最后看过开始截取', () {
      final eps = List<int>.generate(40, (i) => i + 1);
      final sliced = visibleHomeEps(
        eps,
        isWatched: (ep) => ep <= 20,
        startAtLast: true,
        maxLength: 8,
      );
      expect(sliced.first, 20);
      expect(sliced.length, 8);
    });

    test('关闭时从首个未看附近截取', () {
      final eps = List<int>.generate(40, (i) => i + 1);
      final sliced = visibleHomeEps(
        eps,
        isWatched: (ep) => ep <= 20,
        startAtLast: false,
        maxLength: 8,
      );
      expect(sliced.contains(21), isTrue);
      expect(sliced.length, lessThanOrEqualTo(15));
    });
  });

  group('epAirKind', () {
    test('看过优先, 否则按放送日分 today/air/na', () {
      final now = DateTime(2026, 8, 13);
      expect(epAirKind('2026-08-13', watched: true, now: now), 'watched');
      expect(epAirKind('2026-08-13', watched: false, now: now), 'today');
      expect(epAirKind('2026-08-01', watched: false, now: now), 'air');
      expect(epAirKind('2026-08-20', watched: false, now: now), 'na');
    });
  });

  group('homeDoingMetaText / weekdayShort', () {
    test('人数行未开 homeOnAir 时追加周几', () {
      expect(weekdayShort(0), '日');
      expect(weekdayShort(7), '日');
      expect(weekdayShort(3), '三');
      expect(
        homeDoingMetaText(doing: 1234, type: 'anime', weekday: 5, onAir: true),
        '1234 人在看 · 周五',
      );
      expect(
        homeDoingMetaText(doing: 12, type: 'book', weekday: 1, onAir: true),
        '12 人在读 · 周一',
      );
      expect(
        homeDoingMetaText(doing: 12, type: 'game', weekday: 0, onAir: true),
        '12 人在玩 · 周日',
      );
      expect(
        homeDoingMetaText(
          doing: 12,
          type: 'anime',
          weekday: 5,
          onAir: true,
          homeOnAir: true,
        ),
        '12 人在看',
      );
      expect(homeDoingMetaText(doing: 0, type: 'anime', onAir: true), '');
    });
  });

  group('homeLeftText / homeNextInfo / joinHomeMeta', () {
    test('季度未看与下沉文案', () {
      expect(calcHomeSeason('2026-04-08'), (year: 2026, quarter: 2));
      expect(
        homeLeftText(
          seasonYear: 2026,
          quarter: 2,
          airedUnwatched: 3,
          type: 'anime',
        ),
        '2026 春 · 3 集未看',
      );
      expect(
        homeLeftText(
          seasonYear: 2026,
          quarter: 2,
          airedUnwatched: 0,
          type: 'anime',
          twoDigitYear: true,
          sink: true,
          hasNewEp: false,
        ),
        '26 春 · 已下沉',
      );
      expect(
        homeLeftText(
          seasonYear: 2026,
          quarter: 1,
          airedUnwatched: 0,
          type: 'book',
        ),
        '2026',
      );
    });

    test('下一集空格分隔或完结', () {
      final now = DateTime(2026, 8, 14);
      expect(
        homeNextInfo(
          eps: [
            (sort: 3, airdate: '2026-08-20'),
            (sort: 4, airdate: '2026-08-27'),
          ],
          now: now,
          showSplit: false,
        ),
        'ep3 26-08-20 (6 天后)',
      );
      expect(
        homeNextInfo(eps: [(sort: 12, airdate: '2026-07-01')], now: now),
        '完结',
      );
      expect(homeNextInfo(eps: const [], now: now), '');
    });

    test('行内人数与季度下话拼接', () {
      expect(
        joinHomeMeta(
          '12 人在看 · 周五',
          left: '26 春 · 3 集未看',
          next: 'ep3 26-08-20 (6 天后)',
        ),
        '12 人在看 · 周五 · 26 春 · 3 集未看 · ep3 26-08-20 (6 天后)',
      );
      expect(joinHomeMeta('', left: '26 春', next: '完结'), '26 春 · 完结');
    });
  });

  group('onairProgressRatios', () {
    test('已看与已放送按总分母缩放, 最小 2%', () {
      expect(onairProgressRatios(watched: 6, aired: 8, total: 12), (
        watched: 0.5,
        aired: 8 / 12,
      ));
      expect(onairProgressRatios(watched: 1, aired: 0, total: 100), (
        watched: 0.02,
        aired: 0.0,
      ));
      expect(onairProgressRatios(watched: 0, aired: 0, total: 0), (
        watched: 0.0,
        aired: 0.0,
      ));
    });
  });

  group('currentOnAir', () {
    test('倒序取最后一集已放送 sort, 第 0 集则 +1', () {
      const eps = [
        (type: 0, sort: 1, status: 'Air', airdate: ''),
        (type: 0, sort: 2, status: 'Air', airdate: ''),
        (type: 0, sort: 3, status: 'NA', airdate: ''),
        (type: 1, sort: 1, status: 'Air', airdate: ''),
      ];
      expect(currentOnAir(eps: eps), 2);
      expect(
        currentOnAir(
          eps: const [
            (type: 0, sort: 0, status: 'Air', airdate: ''),
            (type: 0, sort: 1, status: 'Air', airdate: ''),
            (type: 0, sort: 2, status: 'NA', airdate: ''),
          ],
        ),
        2,
      );
      expect(
        currentOnAir(
          eps: const [
            (type: 0, sort: 0, status: 'Air', airdate: ''),
            (type: 0, sort: 5, status: 'Air', airdate: ''),
            (type: 0, sort: 6, status: 'NA', airdate: ''),
          ],
        ),
        6,
      );
    });

    test('无 status 时按放送日判断', () {
      final now = DateTime(2026, 8, 14);
      expect(
        currentOnAir(
          eps: const [
            (type: 0, sort: 1, status: '', airdate: '2026-08-07'),
            (type: 0, sort: 2, status: '', airdate: '2026-08-14'),
            (type: 0, sort: 3, status: '', airdate: '2026-08-21'),
          ],
          now: now,
        ),
        2,
      );
    });

    test('分母取 max(已放送, 总集)', () {
      expect(onairProgressCounts(aired: 8, total: 12), (aired: 8, total: 12));
      expect(onairProgressCounts(aired: 14, total: 12), (aired: 14, total: 14));
    });
  });

  group('homeGridNumColumns / subjectHeaderForeground', () {
    test('手机竖屏 4, 平板 5, 手机横屏 9', () {
      expect(homeGridNumColumns(const Size(390, 844)), 4);
      expect(homeGridNumColumns(const Size(844, 390)), 9);
      expect(homeGridNumColumns(const Size(768, 1024)), 5);
      expect(homeGridNumColumns(const Size(1024, 768)), 5);
    });

    test('未吸顶或暗色用白, 浅色吸顶用黑', () {
      expect(
        subjectHeaderForeground(fixed: false, dark: false),
        const Color(0xFFFFFFFF),
      );
      expect(
        subjectHeaderForeground(fixed: false, dark: true),
        const Color(0xFFFFFFFF),
      );
      expect(
        subjectHeaderForeground(fixed: true, dark: true),
        const Color(0xFFFFFFFF),
      );
      expect(
        subjectHeaderForeground(fixed: true, dark: false),
        const Color(0xFF000000),
      );
    });
  });

  group('collectionRatingLabel / flipCollectBtnHeight', () {
    test('1-10 分中文档位, 0 为空', () {
      expect(collectionRatingLabel(0), '');
      expect(collectionRatingLabel(1), '不忍直视');
      expect(collectionRatingLabel(8), '力荐');
      expect(collectionRatingLabel(10), '超神作');
      expect(collectionRatingLabel(99), '超神作');
    });

    test('手机 44, 平板 50', () {
      expect(flipCollectBtnHeight(const Size(390, 844)), 44);
      expect(flipCollectBtnHeight(const Size(768, 1024)), 50);
    });
  });

  group('homeCountText / shouldSinkHomeItem', () {
    test('四种数字组合与下沉判定', () {
      expect(homeCountText(current: 4, total: 12), '4 / 12');
      expect(homeCountText(current: 4, total: 12, style: 'B'), '4 (12)');
      expect(homeCountText(current: 4, total: 12, style: 'C'), '12 (4)');
      expect(homeCountText(current: 4, total: 12, style: 'D'), '4 / 12');
      expect(homeCountText(current: 12, total: 12, style: 'B'), '12');
      expect(shouldSinkHomeItem(watched: 6, aired: 6), isTrue);
      expect(shouldSinkHomeItem(watched: 5, aired: 6), isFalse);
      expect(shouldSinkHomeItem(watched: 6, aired: 6, pinned: true), isFalse);
    });
  });

  group('todayOnAirWindow / airClockDigits', () {
    test('HH:MM 与 HHMM 都解析成 4 位', () {
      expect(airClockDigits('1930'), 1930);
      expect(airClockDigits('19:30'), 1930);
      expect(airClockDigits(''), 0);
    });

    test('取当前时刻前 10 条加后 1 条再反转', () {
      // calendarFlat 拍平后再 reverse: 周日…周一
      final stamps = [
        70000,
        60000,
        50000,
        42000,
        41900,
        40000,
        30000,
        20000,
        10000,
      ];
      final window = todayOnAirWindow<int>(
        items: stamps,
        stampOf: (s) => s,
        now: DateTime(2026, 8, 13, 19, 10), // Thursday 19:10 → 41910
      );
      expect(window, [
        40000,
        41900,
        42000,
        50000,
        60000,
        70000,
        10000,
        20000,
        30000,
        40000,
        41900,
        42000,
      ]);
    });
  });

  group('homeSortWeight', () {
    test('放送优先今天, APP 优先当季', () {
      final now = DateTime(2026, 8, 13); // 周四, weekday=4 -> %7=4
      expect(
        homeSortWeight(
          DateTime(2026, 8, 13),
          weekday: 4,
          mode: 'onair',
          now: now,
        ),
        0,
      );
      expect(
        homeSortWeight(
          DateTime(2026, 8, 14),
          weekday: 5,
          mode: 'onair',
          now: now,
        ),
        1,
      );
      expect(
        homeSortWeight(
          DateTime(2026, 7, 1),
          weekday: 4,
          mode: 'default',
          now: now,
        ),
        lessThan(
          homeSortWeight(
            DateTime(2025, 1, 1),
            weekday: 1,
            mode: 'default',
            now: now,
          ),
        ),
      );
    });
  });

  group('formatSubjectAirDate / promoteAliasRows', () {
    test('关月份只保留年, 开月份保留年-月', () {
      expect(formatSubjectAirDate('2024-07-12', showMonth: false), '2024');
      expect(formatSubjectAirDate('2024-07-12', showMonth: true), '2024-07');
      expect(formatSubjectAirDate('2024', showMonth: true), '2024');
    });

    test('别名挪到中文名后', () {
      final rows = promoteAliasRows(['话数', '中文名', '放送', '别名'], keyOf: (e) => e);
      expect(rows, ['话数', '中文名', '别名', '放送']);
    });
  });

  group('buildSubjectIcs', () {
    test('含日历头和单集事件', () {
      final ics = buildSubjectIcs(
        subjectId: 12,
        title: '测试番',
        clock: '1930',
        eps: const [(id: 99, sort: 1, name: '第一话', airdate: '2026-08-13')],
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:测试番 ep.1'));
      expect(ics, contains('UID:12-99'));
      expect(ics, contains('DTSTART:20260813T193000'));
      expect(ics, contains('END:VCALENDAR'));
    });
  });

  group('buildWeekOnAirIcs', () {
    test('整周多条目合成一份日历', () {
      final ics = buildWeekOnAirIcs(const [
        (id: 1, title: '番A', airdate: '2026-08-13', clock: '1930'),
        (id: 2, title: '番B', airdate: '2026-08-14', clock: '2200'),
      ]);
      expect(ics, contains('X-WR-CALNAME:Bangumi每日放送'));
      expect(ics, contains('SUMMARY:番A'));
      expect(ics, contains('SUMMARY:番B'));
      expect(ics, contains('DTSTART:20260813T193000'));
    });
  });

  group('subject duration extras', () {
    test('音乐播放时长 327 分 / 多碟加总', () {
      expect(parseMusicDuration('播放时长: 327 分'), '327 min');
      expect(parseMusicDuration('播放时长: 72:27+65:45+69:00'), '206 min');
      expect(parseMusicDuration('艺术家: 无'), '');
    });

    test('剧场版片长优先章节 H:MM:SS', () {
      expect(parseMaxDurationFromEps(const ['1:50:00', '0:24:00']), 110);
      expect(parseMovieDuration('片长: 120 分钟'), 120);
      expect(
        subjectMovieDuration(
          titleLabel: '剧场版',
          epDurations: const ['1:50:00'],
          rawInfo: '片长: 90 分钟',
        ),
        '110 min',
      );
      expect(
        subjectMovieDuration(
          titleLabel: 'TV',
          epDurations: const ['1:50:00'],
          rawInfo: '片长: 90 分钟',
        ),
        '',
      );
    });

    test('未上映横幅只在未来日期或年月显示', () {
      final now = DateTime(2026, 8, 13);
      expect(subjectShowRelease('2027-01-01', now: now), isTrue);
      expect(subjectShowRelease('2020-01-01', now: now), isFalse);
      expect(subjectShowRelease('2027年', now: now), isTrue);
      expect(subjectShowRelease('', now: now), isFalse);
    });

    test('动画类型标签取 infobox 类型', () {
      expect(
        subjectTitleLabel(
          typeText: '动画',
          infobox: const [(key: '类型', value: '剧场版 / TV')],
          tags: const [],
        ),
        '剧场版',
      );
    });

    test('发布时间优先连载开始年', () {
      expect(
        subjectYear(
          infobox: const [
            (key: '连载开始', value: '2024年1月'),
            (key: '发售日', value: '2023-12-01'),
          ],
        ),
        '2024',
      );
      expect(
        subjectYearMonth(
          infobox: const [(key: '连载开始', value: '2024年1月')],
          year: '2024',
        ),
        '2024-01',
      );
    });

    test('未看本篇且放送日未过才可添加提醒', () {
      final now = DateTime(2026, 8, 13);
      expect(
        canAddEpCalendar(
          type: 0,
          airdate: '2026-08-20',
          watched: false,
          now: now,
        ),
        isTrue,
      );
      expect(
        canAddEpCalendar(
          type: 1,
          airdate: '2026-08-20',
          watched: false,
          now: now,
        ),
        isFalse,
      );
      expect(
        canAddEpCalendar(
          type: 0,
          airdate: '2026-08-20',
          watched: true,
          now: now,
        ),
        isFalse,
      );
      expect(
        canAddEpCalendar(
          type: 0,
          airdate: '2026-08-01',
          watched: false,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('t2s', () {
    test('繁体转简体, 非汉字原样保留', () {
      seedCnCharTables(sc: '头发', tc: '頭髮');
      expect(t2s('頭髮'), '头发');
      expect(t2s('abc頭髮123'), 'abc头发123');
      expect(t2s('头发'), '头发');
    });
  });
}
