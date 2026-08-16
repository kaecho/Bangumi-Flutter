import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/discovery/widgets/discovery_html.dart';
import 'package:bangumi/features/discovery/calendar_screen.dart';
import 'package:bangumi/shared/models/timeline.dart';

import 'package:bangumi/features/discovery/yearbook_screen.dart';
import 'package:bangumi/features/discovery/recommend_screen.dart';
import 'package:bangumi/features/discovery/catalog_screen.dart';
import 'package:bangumi/features/discovery/wiki_screen.dart';
import 'package:bangumi/features/discovery/blog_screen.dart';
import 'package:bangumi/features/discovery/staff_screen.dart';

import 'package:bangumi/features/discovery/anitama_screen.dart';
import 'package:bangumi/features/discovery/vib_screen.dart';
import 'package:bangumi/features/discovery/users_screen.dart';
import 'package:bangumi/features/discovery/channel_screen.dart';
import 'package:bangumi/features/discovery/browser_screen.dart';
import 'package:bangumi/features/discovery/tags_screen.dart';

import 'package:bangumi/features/discovery/typerank_screen.dart';
import 'package:bangumi/features/user/smb_screen.dart';
import 'package:bangumi/features/subject/subject_screen.dart';

import 'package:bangumi/core/api/api_endpoints.dart';
import 'package:bangumi/features/discovery/catalog_detail_screen.dart';
import 'package:bangumi/features/discovery/tag_subjects_screen.dart';
import 'package:bangumi/features/discovery/wordcloud_screen.dart';
import 'package:bangumi/features/discovery/rank_screen.dart';
import 'package:bangumi/features/discovery/character_screen.dart';
import 'package:bangumi/features/discovery/dollars_screen.dart';

import 'package:bangumi/features/discovery/widgets/recommend_list.dart';
import 'package:bangumi/features/discovery/series_header.dart';
import 'package:bangumi/features/discovery/series_screen.dart';

import 'package:bangumi/core/storage/settings_store.dart';

import 'package:bangumi/features/discovery/widgets/filter_switch.dart';

import 'package:bangumi/shared/models/subject.dart';
import 'package:bangumi/core/utils/display.dart';

import 'package:bangumi/core/storage/packed_json.dart';
import 'package:bangumi/features/discovery/search_advance.dart';
import 'package:bangumi/features/discovery/typerank_data.dart';
import 'package:bangumi/shared/widgets/likes_grid.dart';

void main() {
  group('discovery_html 解析', () {
    test('parseSubjectList 解析浏览器条目页', () {
      const html = '''
<html><body>
<ul id="browserItemList">
<li id="item_326" class="item odd clearit" >
  <a href="/subject/326" class="subjectCover cover ll coverPortrait">
    <span class="image"><img src="//lain.bgm.tv/r/400/pic/cover/l/a6/66/326_D8wjw.jpg" class="cover" loading="lazy" /></span>
  </a>
  <div class="inner">
    <h3><a href="/subject/326" class="l">攻壳机动队 S.A.C. 2nd GIG</a> <small class="grey">攻殻機動隊 S.A.C. 2nd GIG</small></h3>
    <span class="rank"><small>Rank </small>1</span>
    <p class="info tip">26话 / 2004年1月1日 / 神山健治</p>
    <p class="rateInfo"><span class="starstop-s"><span class="starlight stars9"></span></span> <small class="fade">9.2</small> <span class="tip_j">(10055人评分)</span></p>
  </div>
</li>
</ul>
</body></html>
''';
      final subjects = parseSubjectList(html);
      expect(subjects, hasLength(1));
      final s = subjects.first;
      expect(s.id, 326);
      expect(s.nameCn, '攻壳机动队 S.A.C. 2nd GIG');
      expect(s.name, '攻殻機動隊 S.A.C. 2nd GIG');
      expect(s.rank, 1);
      expect(s.eps, 26);
      expect(s.airDate, '2004-1-1');
      expect(s.rating!.score, closeTo(9.2, 0.001));
      expect(s.rating!.total, 10055);
      expect(s.collected, isFalse);

      expect(
        s.images.medium,
        'https://lain.bgm.tv/r/400/pic/cover/l/a6/66/326_D8wjw.jpg',
      );
    });

    test('parseBlogList 解析全站日志', () {
      const html = '''
<div id="columnA">
<div id="entry_list" class="entry-list ">
<div class="item clearit" data-item-user="1260714" >
  <p class="cover"> <a href="/blog/378382" title="t" class="avatar"> <img src="//lain.bgm.tv/pic/user/l/icon.jpg" class="avatarCover" /> </a> </p>
  <div class="entry">
    <h2 class="title"><a href="/blog/378382" class="l">海角为什么值得选择</a></h2>
    <div class="content"><a href="/blog/378382">正文内容一</a></div>
    <div class="time"> <a href="/user/1260714" class="l">纯</a>&nbsp;· 2026-8-11 20:06&nbsp;· <a href="/blog/378382" class="l">0 回复</a> </div>
  </div>
</div>
</div>
</div>
''';
      final rows = parseBlogList(html);
      expect(rows, hasLength(1));
      expect(rows.first.id, 378382);
      expect(rows.first.title, '海角为什么值得选择');
      expect(rows.first.username, '纯');
      expect(rows.first.userId, 1260714);
      expect(rows.first.time, '2026-8-11 20:06');
      expect(rows.first.replies, 0);
    });

    test('parseTagList 解析标签列表', () {
      const html = '''
<div id="tagList"><a href="/anime/tag/TV" class="l level1">TV</a><small class="grey">(1396928)</small> &nbsp; <a href="/anime/tag/%E6%BC%AB%E7%94%BB%E6%94%B9" class="l level1">漫画改</a><small class="grey">(857,680)</small></div>
''';
      final tags = parseTagList(html);
      expect(tags, hasLength(2));
      expect(tags[0].name, 'TV');
      expect(tags[0].count, 1396928);
      expect(tags[1].name, '漫画改');
      expect(tags[1].count, 857680);
    });

    test('parseGroupList 解析小组列表', () {
      const html = '''
<ul class="groupsLarge">
<li><a href="/group/pixiv" title="pixiv"><span class="pictureFrameGroup"><span class="image"><img src="//lain.bgm.tv/pic/icon/l/000/00/00/84.jpg"></span><span class="overlay"></span></span>pixiv</a><br /><small class="feed">16,038 位成员</small></li>
</ul>
''';
      final groups = parseGroupList(html);
      expect(groups, hasLength(1));
      expect(groups.first.name, 'pixiv');
      expect(groups.first.title, 'pixiv');
      expect(groups.first.members, 16038);
      expect(
        groups.first.icon,
        'https://lain.bgm.tv/pic/icon/l/000/00/00/84.jpg',
      );
    });

    test('parseTopicRows 解析 Dollars 论坛主题', () {
      const html = '''
<table class="topic_list"><tbody>
<tr class="topic even" data-item-user="553331">
  <td class="subject"><a href="/group/topic/358379" title="嗨多磨" class="l">嗨多磨</a></td>
  <td class="author"><a href="/user/553331" class="l">樱井龙之介</a></td>
  <td class="posts">2</td>
  <td class="lastpost"><small class="time">2020-8-18 17:53</small></td>
</tr>
</tbody></table>
''';
      final rows = parseTopicRows(html);
      expect(rows, hasLength(1));
      expect(rows.first.id, 358379);
      expect(rows.first.title, '嗨多磨');
      expect(rows.first.username, '樱井龙之介');
      expect(rows.first.replies, 2);
      expect(rows.first.lastTime, '2020-8-18 17:53');
    });

    test('parseV0Collections 解析收藏分页响应', () {
      final items = parseV0Collections({
        'total': 1,
        'limit': 100,
        'offset': 0,
        'data': [
          {
            'subject_id': 246430,
            'type': 3,
            'ep_status': 12,
            'updated_at': '2026-07-01T00:00:00.000+08:00',
            'subject': {
              'id': 246430,
              'name': 'Sample Anime',
              'name_cn': '示例动画',
              'images': {'large': 'https://lain.bgm.tv/pic/cover/l/x.jpg'},
              'rank': 42,
              'score': 8.5,
              'tags': [
                {'name': '原创', 'count': 1},
              ],
            },
          },
        ],
      });
      expect(items, hasLength(1));
      expect(items.first.subjectId, 246430);
      expect(items.first.type, 3);
      expect(items.first.epStatus, 12);
      expect(items.first.subject.displayName, '示例动画');
      expect(items.first.subject.rank, 42);
    });
    test('parseWiki 解析编辑与入库分段', () {
      const html = '''
<html><body>
<ul class="wikiStats"><li><span>编辑</span><span class="num">12</span></li></ul>
<ul id="wiki_act-all"><li><a href="/subject/1" class="l" target="_blank">条目A</a><small class="grey"><a href="/user/1">Alice</a></small><span class="rr">今天</span></li></ul>
<ul id="wiki_act-lock"><li><a href="/subject/2" class="l" target="_blank">锁定B</a></li></ul>
<ul id="latest_2"><li><a href="/subject/3" class="l">新番C</a></li></ul>
</body></html>
''';
      final data = parseWiki(html);
      expect(data.counts, isNotEmpty);
      expect(data.all, hasLength(1));
      expect(data.all.first.name, '条目A');
      expect(data.lock, hasLength(1));
      expect(data.of('latest_2').first.name, '新番C');
    });

    test('parseMonoRecents 解析收藏人物近况', () {
      const html = '''
<div id="columnCrtBrowserB">
<ul id="browserItemList">
<li id="item_8" class="item">
  <img class="cover" src="//lain.bgm.tv/pic/cover/s/8.jpg" />
  <h3><span class="ll subject_type_2"></span><a class="l" href="/subject/8">代码帝国</a> <small class="grey">Code Geass</small></h3>
  <p class="info">2026-8-1 / 动画</p>
  <span class="starlight stars9"></span>
  <span class="rateInfo"><span class="tip_j">(12人评分)</span></span>
  <div class="actorBadge">
    <a class="avatar" href="/character/1"><img src="//lain.bgm.tv/pic/crt/s/1.jpg" /></a>
    <a class="l" href="/character/1">鲁路修</a>
    <small class="grey">主角</small>
  </div>
</li>
</ul>
</div>
<div id="footer"></div>
''';
      final items = parseMonoRecents(html);
      expect(items, hasLength(1));
      expect(items.first.id, 8);
      expect(items.first.name, '代码帝国');
      expect(items.first.nameJp, 'Code Geass');
      expect(items.first.star, 9);
      expect(items.first.actors, hasLength(1));
      expect(items.first.actors.first.$1, 'character/1');
      expect(items.first.actors.first.$3, '鲁路修');
    });

    test('parseDollars 解析聊天室条目', () {
      const html = '''
<div id="toolBox">在线: 12</div>
<div id="chatList">
  <ul>
    <li id="chat_12345678901">
      <div class="icon"><img class="avatar" src="//lain.bgm.tv/pic/user/m/000/00/00/1.jpg" /><p>甲</p></div>
      <div class="content" style="color:#f00"><p>你好</p></div>
    </li>
  </ul>
</div>
''';
      final data = parseDollars(html);
      expect(data.online, '12');
      expect(data.list, hasLength(1));
      expect(data.list.first.id, '1234567890');
      expect(data.list.first.nickname, '甲');
      expect(data.list.first.msg, '你好');
      expect(data.list.first.avatar, contains('lain.bgm.tv'));
    });

    test('parseCatalogDetailExtra 解析收藏与取消链接', () {
      const html = '''
<div id="header"><h1>目录</h1></div>
<div class="grp_box">
  <a class="btnPink" href="/index/8/erase_collect?gh=abc">取消收藏</a>
  <div class="tip_j">
    <a class="l" href="/user/lily">作者</a>
    <span class="tip">创建</span>
    <span class="tip">更新</span>
    <span class="tip">12 人收藏</span>
  </div>
</div>
<div class="progress"><small>完成 3/10</small></div>
<ul class="timeline_img">
  <li class="clearit"></li>
  <li class="clearit"></li>
  <li class="clearit"></li>
  <li class="clearit"></li>
  <li class="clearit"></li>
</ul>
<div class="browserCrtList">
  <div><a class="l" href="/character/1">角色甲</a><img class="avatar" src="//lain.bgm.tv/pic/crt/g/1.jpg"></div>
  <div><a class="l" href="/person/2">人物乙</a><img class="avatar" src="//lain.bgm.tv/pic/crt/g/2.jpg"></div>
</div>
<div id="footer"></div>
''';
      final extra = parseCatalogDetailExtra(html);
      expect(extra.collected, isTrue);
      expect(extra.byeUrl, contains('erase_collect'));
      expect(extra.collect, contains('12'));
      expect(extra.progress, contains('3/10'));
      expect(extra.replyCount, 5);
      expect(catalogReplyText(extra.replyCount), '5+');
      expect(extra.userId, 'lily');
      expect(extra.characters.single.title, '角色甲');
      expect(extra.persons.single.title, '人物乙');
      expect(catalogTypeData(extra).map((e) => e.$1).toList(), ['角色', '人物']);
    });

    test('目录 Extra 排序收藏文案对齐原版', () {
      expect(catalogSortLabel('2'), '评分');
      expect(catalogCollectLabel('uncollect'), '不看收藏');
      expect(catalogReplyText(0), '');
      expect(catalogReplyText(3), '3');
      final items = [
        const Subject(
          id: 1,
          name: 'A',
          airDate: '2020-01-01',
          images: SubjectImages(),
          rating: Rating(score: 6, total: 10),
          collected: true,
        ),
        const Subject(
          id: 2,
          name: 'B',
          airDate: '2024-01-01',
          images: SubjectImages(),
          rating: Rating(score: 8, total: 3),
          collected: false,
        ),
      ];
      expect(catalogFilterCollect(items, 'collected').single.id, 1);
      expect(catalogSortSubjects(items, '2').first.id, 2);
    });

    test('parseChannel 解析好友最近关注', () {
      const html = '''
<div class="columns">
  <ul class="coversSmall">
    <li>
      <a href="/subject/12" title="cowboy bebop"><img src="//lain.bgm.tv/pic/cover/s/12.jpg"></a>
      <p class="info"><a class="l" href="/user/42"><img src="//lain.bgm.tv/pic/user/s/42.jpg">用户A</a> 在看</p>
    </li>
    <li>
      <a href="/subject/13" title="no"><img src="/img/no_img.gif"></a>
    </li>
  </ul>
</div>
''';
      final data = parseChannel(html);
      expect(data.friends, hasLength(1));
      expect(data.friends.single.id, 12);
      expect(data.friends.single.userId, '42');
      expect(data.friends.single.userName, '用户A');
      expect(data.friends.single.action, '在看');
      expect(data.friends.single.avatar, contains('42.jpg'));
    });
  });

  group('推荐评分', () {
    test('calcRecommendScore 高分条目得分更高', () {
      final good = calcRecommendScore(
        V0CollectionItem(
          subjectId: 1,
          type: 2,
          updatedAt: '2026-08-10T00:00:00.000+08:00',
          subject: Subject(
            id: 1,
            name: 'good',
            images: const SubjectImages(),
            rank: 10,
            rating: const Rating(score: 9.0, total: 100),
            tags: const [Tag(name: '原创', count: 1)],
          ),
        ),
      );
      final poor = calcRecommendScore(
        V0CollectionItem(
          subjectId: 2,
          type: 5,
          updatedAt: '2020-01-01T00:00:00.000+08:00',
          subject: const Subject(id: 2, name: 'poor', images: SubjectImages()),
        ),
      );
      expect(good, greaterThan(poor));
    });

    test('关闭条目排名维度后高排名加分消失', () {
      final item = V0CollectionItem(
        subjectId: 1,
        type: 2,
        subject: Subject(
          id: 1,
          name: 'rank',
          images: const SubjectImages(),
          rank: 10,
          rating: const Rating(score: 8, total: 10),
        ),
      );
      final on = calcRecommendScore(item);
      final off = calcRecommendScore(
        item,
        likeRec: const [1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
      );
      expect(on, greaterThan(off));
    });

    test('推荐维度默认 10 项', () {
      expect(kLikeRecReasons, hasLength(10));
    });
  });

  group('calendarFilterOptions', () {
    test('从当周标签抽出改编/标签/制作并计数', () {
      const images = SubjectImages();
      final days = [
        CalendarDay(
          items: [
            Subject(
              id: 1,
              images: images,
              tags: const [
                Tag(name: '原创', count: 10),
                Tag(name: '科幻', count: 8),
                Tag(name: 'MAPPA', count: 3),
              ],
            ),
            Subject(
              id: 2,
              images: images,
              tags: const [
                Tag(name: '漫画改', count: 9),
                Tag(name: '科幻', count: 5),
                Tag(name: '京都动画', count: 4),
              ],
            ),
          ],
        ),
      ];
      final filters = calendarFilterOptions(days);
      expect(filters.adapts, containsAll(['全部', '原创 (1)', '漫画改 (1)']));
      expect(filters.tags.first, '全部');
      expect(filters.tags, contains('科幻 (2)'));
      expect(filters.studios, containsAll(['全部', 'MAPPA (1)', '京都动画 (1)']));
    });
  });

  group('yearbook layout', () {
    test('2022 横幅后接 2018-2021 图块, 更早两年一排', () {
      expect(kYearbookBannerYear, 2022);
      expect(kYearbookBlockYears, [2021, 2020, 2019, 2018]);
      expect(kYearbookGridYears, [
        2017,
        2016,
        2015,
        2014,
        2013,
        2012,
        2011,
        2010,
      ]);
      expect(kYearbookYears, containsAll([2024, 2022, 2018, 2010]));
    });
  });

  group('recommend category', () {
    test('默认映射动画, 选项含全部类型', () {
      expect(recommendCategoryLabel(0), '默认');
      expect(recommendCategoryLabel(2), '动画');
      expect(recommendCategoryLabel(6), '三次元');
      expect(kRecommendCategoryOptions.first.$2, '默认');
      expect(
        [for (final e in kRecommendCategoryOptions) e.$2],
        ['默认', '动画', '书籍', '游戏', '音乐', '三次元'],
      );
    });
  });

  group('catalog toolbar', () {
    test('整合关键字保留数量并按前缀取值', () {
      expect(kCatalogFilterKeys.first, '不限 (2000)');
      expect(kCatalogFilterKeys[1].split(' (').first, '动画');
      expect(kCatalogTypes.map((e) => e.$2).toList(), ['整合', '热门', '最新']);
    });
    test('目录更多对齐原版工具栏和分页器锁定', () {
      expect(
        catalogMoreItems(
          fixedFilter: true,
          fixedPagination: false,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '网页版查看', '补充说明', '工具栏〔锁定〕', '分页器〔浮动〕'],
      );
    });
  });

  group('wiki defaults', () {
    test('默认入库 tab, 二级全部', () {
      expect(kWikiDefaultCate, 2);
      expect(kWikiDefaultKind, 'latest_all');
    });
  });

  group('catalog copy', () {
    test('从跳转地址解析新建目录 id', () {
      expect(parseCreatedCatalogId('https://bgm.tv/index/42'), 42);
      expect(parseCreatedCatalogId('/index/8?foo=1'), 8);
      expect(parseCreatedCatalogId('ok'), isNull);
    });
    test('目录详情更多对齐原版复制浏览器网页版', () {
      expect(catalogDetailMoreItems().map((e) => e.$2).toList(), [
        '复制并创建目录',
        '浏览器查看',
        '网页版查看',
      ]);
    });

    test('目录详情标题字号按视觉长度', () {
      expect(catalogDetailTitleSize('短'), 14);
      expect(catalogDetailTitleSize('这是一个很长的目录标题'), 12);
    });
  });

  group('discovery Extra', () {
    test('找番剧 Extra 默认列表布局', () {
      expect(SettingsStore.instance.discoveryList, isTrue);
    });

    test('找条目频道条对齐原版 FILTER_SWITCH_DS', () {
      expect(kFilterSwitchDs.map((e) => e.$1).toList(), [
        '番剧',
        '游戏',
        '漫画',
        '文库',
        'ADV',
        'NSFW',
      ]);
      expect(kFilterSwitchDs.map((e) => e.$2).toList(), [
        '/anime',
        '/game',
        '/manga',
        '/wenku',
        '/adv',
        '/nsfw',
      ]);
      expect(kFilterSwitchDs.map((e) => e.$3).toList(), [
        5113,
        2837,
        10622,
        2740,
        3600,
        5987,
      ]);
    });

    test('业界资讯来源只走顶栏菜单', () {
      expect(kAnitamaSources.map((e) => e.$2).toList(), ['机核', '异世界', '游民星空']);
    });

    test('VIB 标题日到改至, 菜单第一项是小组讨论', () {
      expect(
        formatVibHeading(const VibMonth(title: '202507', desc: '7月1日到7月31日')),
        '202507 (7月1至7月31日)',
      );
      expect(kVibGroupLabel, '小组讨论');
    });

    test('社区项目讨论帖和小组标签分开', () {
      expect(communityTopicKind('https://bgm.tv/group/topic/445853'), '讨论');
      expect(communityTopicKind('https://bgm.tv/group/qpz'), '小组');
      expect(
        fillCommunityUserId('https://x/?user=[USER_ID]', 'sakura'),
        'https://x/?user=sakura',
      );
    });

    test('频道类型只走顶栏菜单, 含音乐', () {
      expect(kChannelTypes.map((e) => e.$2).toList(), [
        '动画',
        '书籍',
        '三次元',
        '游戏',
        '音乐',
      ]);
    });

    test('索引类型含音乐, 排序对齐原版 BROWSER_SORT', () {
      expect(kBrowserTypes.map((e) => e.$2).toList(), [
        '动画',
        '书籍',
        '音乐',
        '游戏',
        '三次元',
      ]);
      expect(kBrowserSorts.map((e) => e.$1).toList(), ['', 'rank', 'date']);
      expect(browserYears(2026).first, 2026);
      expect(browserYears(2026).last, 1949);
      expect(
        htmlBrowser('anime', airtime: '2026-8', sort: 'date'),
        '/anime/browser/airtime/2026-8?sort=date',
      );
    });

    test('每日放送顶栏菜单对齐原版 DATA + toolBar', () {
      expect(
        calendarMoreItems(
          listLayout: true,
          collectedOnly: false,
          expandUnknown: false,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '网页版查看', '补充说明', '布　局〔列表〕', '收　藏〔显示〕', '未知时间番剧〔不显示〕'],
      );
    });

    test('AI 推荐顶栏菜单是说明和帖子讨论', () {
      expect(kRecommendMoreItems.map((e) => e.$2).toList(), ['说明', '帖子讨论']);
    });

    test('分类排行标题带类型中文, 含音乐', () {
      expect(typeRankTypeCn('anime'), '动画');
      expect(typeRankTypeCn('music'), '音乐');
      expect(kTypeRankTypes.map((e) => e.$1).toList(), [
        'anime',
        'book',
        'music',
        'game',
        'real',
      ]);
    });

    test('分类排行书签进对应标签页', () {
      expect(typeRankBookmarkPath('anime', 'TV'), '/tags/anime/TV');
      expect(typeRankBookmarkPath('book', ''), '/tags');
    });

    test('本地管理顶栏只留新增服务', () {
      expect(kSmbMoreItems.map((e) => e.$2).toList(), ['新增服务']);
    });

    test('条目更多文案对齐原版 MENU_DS', () {
      expect(subjectMoreItems(8).map((e) => e.$2).toList(), [
        '浏览器查看〔8〕',
        '复制链接',
        '复制分享',
        '拼图分享',
        '客户端网页版本分享',
        '跳转管理',
        '设置',
      ]);
    });

    test('用户标签标题是类型加点标签', () {
      expect(tagSubjectsTitle('anime', 'TV'), '动画 · TV');
      expect(tagSubjectsTitle('music', ''), '音乐标签');
      expect(tagTypeCn('real'), '三次元');
    });

    test('用户标签更多对齐原版浏览器和工具栏', () {
      expect(
        tagSubjectsMoreItems(
          fixed: true,
          list: false,
          collected: true,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '工具栏〔锁定〕', '布　局〔网格〕', '收　藏〔显示〕'],
      );
    });

    test('词云标题带名字, 空则词云', () {
      expect(wordCloudTitle('CLANNAD'), 'CLANNAD的词云');
      expect(wordCloudTitle(' sakura '), 'sakura的词云');
      expect(wordCloudTitle(''), '词云');
      expect(wordCloudTitle(null), '词云');
    });

    test('排行榜更多对齐原版工具栏锁定和分页器', () {
      expect(
        rankMoreItems(
          fixed: true,
          pagination: true,
          list: true,
          collected: true,
          fixedPagination: true,
        ).map((e) => e.$2).toList(),
        [
          '浏览器查看',
          '网页版查看',
          '工具栏〔锁定〕',
          '加　载〔分页加载〕',
          '布　局〔列表〕',
          '收　藏〔显示〕',
          '分页器〔锁定〕',
        ],
      );
      expect(
        rankMoreItems(
          fixed: false,
          pagination: false,
          list: false,
          collected: false,
          fixedPagination: false,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '网页版查看', '工具栏〔浮动〕', '加　载〔到底加载〕', '布　局〔网格〕', '收　藏〔不显示〕'],
      );
    });

    test('排行榜默认锁定工具栏和分页器', () {
      const s = RankState();
      expect(s.fixed, isTrue);
      expect(s.fixedPagination, isTrue);
      expect(s.pagination, isTrue);
      expect(s.copyWith(fixed: false, fixedPagination: false).fixed, isFalse);
    });

    test('索引更多对齐原版工具栏默认浮动', () {
      expect(
        browserMoreItems(
          fixed: false,
          list: true,
          collected: true,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '网页版查看', '工具栏〔浮动〕', '布　局〔列表〕', '收　藏〔显示〕'],
      );
    });

    test('人物浏览器近况走 update, 其余走用户人物页', () {
      expect(
        characterBrowserUrl(recents: true, userId: 'sakura'),
        contains('/mono/update'),
      );
      expect(
        characterBrowserUrl(recents: false, userId: ''),
        contains('/mono/update'),
      );
      expect(
        characterBrowserUrl(recents: false, userId: 'sakura'),
        contains('/user/sakura/mono'),
      );
    });
    test('人物标题按 userName 区分我和 TA', () {
      expect(characterTitle(null), '我的人物');
      expect(characterTitle(''), '我的人物');
      expect(characterTitle('sakura'), 'TA的人物');
      expect(characterShowRecents(null), isTrue);
      expect(characterShowRecents('sakura', meId: 'sakura'), isTrue);
      expect(characterShowRecents('sakura', meId: 'other'), isFalse);
    });

    test('人物近况分割线插在最后一个未来日期之后', () {
      final now = DateTime(2026, 8, 16);
      expect(isRecentFutureDate('2026年8月20日放送', now), isTrue);
      expect(isRecentFutureDate('2026-08-10 播出', now), isFalse);
      expect(recentDividerLabel(now), '26-08-16');
      expect(recentDividerOffset(0), 0);
      expect(recentDividerOffset(3), 2 * kRecentItemHeight);
      expect(
        recentDividerIndex([
          const MonoRecentItem(info: '2026年8月20日'),
          const MonoRecentItem(info: '2026年8月18日'),
          const MonoRecentItem(info: '2026年8月10日'),
        ], now),
        2,
      );
    });

    test('Dollars 标题和回顶条件对齐原版', () {
      expect(dollarsTitle('12'), 'ONLINE：12');
      expect(dollarsTitle(''), 'DOLLARS');
      expect(dollarsTitle(null), 'DOLLARS');
      expect(
        dollarsShowScrollTop(compose: false, pixels: 1600, windowHeight: 800),
        isTrue,
      );
      expect(
        dollarsShowScrollTop(compose: true, pixels: 1600, windowHeight: 800),
        isFalse,
      );
      expect(
        dollarsShowScrollTop(compose: false, pixels: 799, windowHeight: 800),
        isFalse,
      );
    });

    test('关联系列更多默认锁定工具栏', () {
      expect(seriesMoreItems(fixed: true).map((e) => e.$2).toList(), [
        '说明',
        '工具栏〔锁定〕',
      ]);
      expect(seriesMoreItems(fixed: false).map((e) => e.$2).toList(), [
        '说明',
        '工具栏〔浮动〕',
      ]);
    });

    test('关联系列可按放送年和收藏状态过滤', () {
      const a = SeriesItem(
        subject: Subject(
          id: 1,
          nameCn: '甲',
          airDate: '2024-01-01',
          images: SubjectImages(),
        ),
        collectionType: 2,
      );
      const b = SeriesItem(
        subject: Subject(
          id: 2,
          nameCn: '乙',
          airDate: '2025-04-01',
          images: SubjectImages(),
        ),
        collectionType: 3,
      );
      const groups = [
        SeriesGroup(name: '甲', items: [a, b]),
      ];
      expect(
        filterSeriesGroups(
          groups,
          sort: '',
          filter: '',
          airtime: '2025',
          status: '',
        ).single.items.map((e) => e.subject.id),
        [2],
      );
      expect(
        filterSeriesGroups(
          groups,
          sort: '',
          filter: '',
          airtime: '',
          status: '看过',
        ).single.items.map((e) => e.subject.id),
        [1],
      );
      expect(seriesAirtimeYears(2026).take(3).toList(), ['全部', '2026', '2025']);
    });

    test('日志和新番更多含网页版查看', () {
      expect(kBlogListMoreItems.map((e) => e.$2).toList(), ['浏览器查看', '网页版查看']);
      expect(kStaffMoreItems.map((e) => e.$2).toList(), ['浏览器查看', '网页版查看']);
    });
    test('标签更多含网页版查看', () {
      expect(kTagsMoreItems.map((e) => e.$2).toList(), ['浏览器查看', '网页版查看']);
    });

    test('打包标签搜索规范化并最多 10 条', () {
      seedCnCharTables(sc: '龙', tc: '龍');
      expect(normalizeSearch(' 龍 猫 '), '龙猫');
      expect(isSearchAdvanceId('8'), isTrue);
      expect(isSearchAdvanceId('CLANNAD'), isFalse);
      final hits = matchSearchAdvance({
        'CLANNAD': 51,
        'CLANNAD AFTER STORY': 52,
        '攻壳机动队': 326,
        for (var i = 0; i < 12; i++) '动画$i': i + 1,
      }, 'cla');
      expect(hits.map((e) => e.title), ['CLANNAD AFTER STORY', 'CLANNAD']);
      expect(matchSearchAdvance({'动画1': 1}, 'x'), isEmpty);
    });

    test('打包人物联想解析封面路径', () {
      final mono = parseSearchAdvanceMono({
        'i': 2481,
        'n': '京都动画',
        'c': 'c3/e4/2481_prsn_7FM5M',
        'r': 1653,
        'p': 1,
      });
      expect(mono?.path, '/mono/person/2481');
      expect(mono?.cover, contains('2481_prsn_7FM5M'));
      expect(matchSearchAdvanceMono([mono!], '京都').single.name, '京都动画');
    });

    test('分类排行标题带快照条数', () {
      expect(typeRankTitle('anime', 'TV', total: 100), '分类排行 · 动画 · TV (100)');
      expect(typeRankTitle('music', '摇滚'), '分类排行 · 音乐 · 摇滚');
      expect(
        typeRankIdsFromMap({
          'TV': [8, 12, 0, '51'],
        }, 'TV'),
        [8, 12, 51],
      );
      expect(typeRankBetterPercent([1, 10, 20, 30], 1), 99);
      expect(typeRankBetterPercent([1, 10, 20, 30], 25), 25);
      expect(typeRankBetterLabel(null), '--');
      expect(typeRankBetterLabel(90), '优于90%');
    });

    test('贴贴网格时间线 8 个帖子 12 个', () {
      expect(likesGridData(kLikeTypeRakuen), hasLength(12));
      expect(likesGridData(kLikeTypeTimeline), hasLength(8));
      expect(likesGridData(kLikeTypeSay), hasLength(8));
      expect(likesGridEmoji(54), 38);
      expect(bgmSmileUrl(38), 'https://bgm.tv/img/smiles/tv/38.gif');
    });

    test('分类排行打包计数可注入', () {
      seedPackedJson('assets/data/typerank/anime-ids.json', {
        'TV': [1, 2, 3],
      });
      expect(
        typeRankIdsFromMap({
          'TV': [1, 2, 3],
        }, 'TV'),
        [1, 2, 3],
      );
      clearPackedJson();
    });

    test('用户标签 extra 排序和放送年', () {
      expect(tagOrderLabel('rank'), '排名');
      expect(tagOrderLabel('collects'), '收藏');
      expect(tagSubjectsAirtime('', '4'), '');
      expect(tagSubjectsAirtime('2024', ''), '2024');
      expect(tagSubjectsAirtime('2024', '4'), '2024-4');
      expect(kTagOrders.map((e) => e.$2).toList(), [
        '排名',
        '热度',
        '收藏',
        '日期',
        '名称',
      ]);
    });
  });
}
