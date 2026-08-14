import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/utils/display.dart';
import 'package:bangumi/shared/models/subject.dart';

void main() {
  group('cnjp', () {
    test('中文优先与原名优先', () {
      expect(cnjp('魔法少女まどか☆マギカ', '魔法少女小圆', cnFirst: true), '魔法少女小圆');
      expect(cnjp('魔法少女まどか☆マギカ', '魔法少女小圆', cnFirst: false), '魔法少女まどか☆マギカ');
      expect(cnjp('', '魔法少女小圆', cnFirst: false), '魔法少女小圆');
      expect(cnjp('まどか', '', cnFirst: true), 'まどか');
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
        applyCoverQuality(
          'http://lain.bgm.tv/pic/cover/c/ab/cd.jpg',
          'medium',
        ),
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
}
