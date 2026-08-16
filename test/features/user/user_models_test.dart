import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/user/origin_utils.dart';
import 'package:bangumi/core/api/api_endpoints.dart';

import 'package:bangumi/features/user/user_models.dart';
import 'package:bangumi/shared/models/collection.dart';
import 'package:bangumi/features/user/user_screen.dart';
import 'package:bangumi/features/user/zone_screen.dart';
import 'package:bangumi/features/user/friends_screen.dart';
import 'package:bangumi/features/user/user_timeline_screen.dart';
import 'package:bangumi/features/user/setting_screen.dart';
import 'package:bangumi/features/user/server_status_screen.dart';
import 'package:bangumi/features/user/user_notes.dart';
import 'package:bangumi/features/user/pm_screen.dart';
import 'package:bangumi/features/user/milestone_screen.dart';
import 'package:bangumi/features/user/qiafan_screen.dart';

void main() {
  group('v0SubjectTypeInt', () {
    test('类型映射', () {
      expect(v0SubjectTypeInt('book'), 1);
      expect(v0SubjectTypeInt('anime'), 2);
      expect(v0SubjectTypeInt('music'), 3);
      expect(v0SubjectTypeInt('game'), 4);
      expect(v0SubjectTypeInt('real'), 6);
      expect(v0SubjectTypeInt('unknown'), 2);
    });
  });

  group('parseUserTimeline', () {
    const html = '''
<div id="timeline">
  <h4 class="Header">2026-7-4</h4>
  <ul>
    <li id="tml_69669186" class="clearit tml_item">
      <a href="/user/sakura" class="l">樱</a>
      <span class="info_full clearit">在玩 <a href="https://bgm.tv/subject/548128" data-subject-name-cn="节奏天国 奇迹之星" data-subject-id="548128" data-subject-name="リズム天国 ミラクルスターズ" class="l">リズム天国 ミラクルスターズ</a>

        <div class="card">
          <div class="container">
            <a href="https://bgm.tv/subject/548128"><span class="cover"><img src="//lain.bgm.tv/pic/cover/l/13/03/548128.jpg" /></span></a>
            <div class="inner">
              <p class="title"><a href="https://bgm.tv/subject/548128">节奏天国 奇迹之星</a></p>
              <p class="rateInfo"><span class="starlight stars8"></span> <small class="fade">7.9</small> <small class="rate_total">(77)</small></p>
            </div>
          </div>
        </div>
        <div class="post_actions date"><span title="2026-7-4 14:37" class="titleTip">1月8天前</span> <a class="tml_del" href="/erase/tml_69669186?gh=abc">del</a></div>
      </span>

    </li>
  </ul>
</div>
''';

    test('按日期分组并解析条目', () {
      final groups = parseUserTimeline(html);
      expect(groups.length, 1);
      expect(groups.first.date, '2026-7-4');
      expect(groups.first.items.length, 1);

      final item = groups.first.items.first;
      expect(item.id, 69669186);
      expect(item.createdAt, '2026-7-4 14:37');
      expect(item.content, contains('在玩'));
      expect(item.content, contains('节奏天国 奇迹之星'));
      expect(item.subject, isNotNull);
      expect(item.subject!.id, 548128);
      expect(item.subject!.nameCn, '节奏天国 奇迹之星');
      expect(item.subject!.images.common, contains('548128.jpg'));
      expect(item.subject!.rating!.score, 7.9);
      expect(item.clearHref, contains('erase/tml_69669186'));
      expect(item.user?.username, 'sakura');
      expect(item.user?.nickname, '樱');
    });

    test('无列表返回空', () {
      expect(parseUserTimeline('<html><body>空</body></html>'), isEmpty);
    });
  });

  group('parseUserBlogs', () {
    const html = '''
<div id="entry_list">
  <div class="item clearit">
    <p class="cover">
      <a href="/blog/273029" title="Alter 奥丁领域" class="avatar"><img src="//lain.bgm.tv/pic/photo/l/c4/ca/1.jpg" class="avatarCover" /></a>
    </p>
    <div class="entry">
      <h2 class="title"><a href="/blog/273029" class="l">Alter 奥丁领域 Velvet w/ Cornelius</a></h2>
      <div class="content"><a href="/blog/273029">有始有终</a></div>
      <div class="tools">
        <div class="time">2016-5-21 18:02&nbsp;· <a href="/blog/273029" class="l">6 回复</a></div>
        <div class="tags"><a href=""><span class="badge_tag">alter</span></a> <a href=""><span class="badge_tag">figure</span></a></div>
      </div>
    </div>
  </div>
</div>
''';

    test('解析日志项', () {
      final blogs = parseUserBlogs(html);
      expect(blogs.length, 1);
      final blog = blogs.first;
      expect(blog.id, '273029');
      expect(blog.title, 'Alter 奥丁领域 Velvet w/ Cornelius');
      expect(blog.cover, contains('https://'));
      expect(blog.content, '有始有终');
      expect(blog.time, '2016-5-21 18:02');
      expect(blog.replies, '6');
      expect(blog.tags, ['alter', 'figure']);
    });
  });

  group('parseUserCatalogs', () {
    const html = '''
<div id="timeline" class="index-list">
  <ul>
    <li id="item_87787" class="clearit tml_item index-item">
      <span class="info clearit">
        <div class="clearit">
          <span class="stats tip rr">
            <span class="ico_subject_type num subject_type_2 ll"><span class="num">4</span></span>
            <span class="ico_subject_type num subject_type_6 ll"><span class="num">3</span></span>
          </span>
          <a href="/index/87787" class="l"><h3>我的 2025 年度精选</h3></a>
        </div>
        <span class="time tip_i">创建 <span class="tip_j">2026-1-4 19:49</span> · 更新 <span class="tip_j">2026-1-4 19:49</span></span>
        <span class="desc">精选目录</span>
      </span>
    </li>
  </ul>
</div>
''';

    test('解析目录项', () {
      final catalogs = parseUserCatalogs(html);
      expect(catalogs.length, 1);
      final catalog = catalogs.first;
      expect(catalog.id, '87787');
      expect(catalog.title, '我的 2025 年度精选');
      expect(catalog.desc, '精选目录');
      expect(catalog.counts['2'], 4);
      expect(catalog.counts['6'], 3);
      expect(catalog.total, 7);
      expect(catalog.created, '2026-1-4 19:49');
    });
  });

  group('parseUserFriends', () {
    const html = '''
<div id="columnUserSingle" class="column">
  <ul id="memberUserList" class="usersMedium">
    <li class="user">
      <div class="userContainer"><strong>
        <a href="/user/2" class="avatar">
          <span class="userImage"><span class="avatarNeue avatarSize48 ll" style="background-image:url('//lain.bgm.tv/pic/user/l/000/00/00/2.jpg?r=1')"></span></span>
          陈永仁</a>
      </strong></div>
    </li>
  </ul>
</div>
''';

    test('解析好友项', () {
      final friends = parseUserFriends(html);
      expect(friends.length, 1);
      final friend = friends.first;
      expect(friend.userId, '2');
      expect(friend.userName, '陈永仁');
      expect(friend.avatar, contains('https://'));
      expect(friend.avatar, contains('2.jpg'));
    });
  });

  group('parseUserMono', () {
    const html = '''
<div id="columnA" class="column">
  <ul class="browserCoverMedium coverList full clearit">
    <li class="clearit">
      <a href="/character/131623" title="Mickey Mouse"><img src="//lain.bgm.tv/pic/crt/m/bb/16/131623.jpg" class="avatarCover avatarTop" /></a>
      <a href="/character/131623" class="title">Mickey Mouse</a>
      <p class="info"></p>
    </li>
  </ul>
</div>
''';

    test('解析人物项', () {
      final monos = parseUserMono(html);
      expect(monos.length, 1);
      expect(monos.first.id, 'character/131623');
      expect(monos.first.name, 'Mickey Mouse');
      expect(monos.first.avatar, contains('https://'));
    });
  });

  group('parsePmInbox', () {
    const html = '''
<div class="pm-conversation-list">
  <a class="pm-conversation-item pm_new" href="/pm/conversation/123.chii">
    <span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/l/000/00/00/42.jpg')"></span>
    <span class="pm-conversation-name">测试用户</span>
    <span class="pm-conversation-date">2026-8-1</span>
    <span class="pm-conversation-desc">Re: 你好 / 这是内容</span>
  </a>
</div>
''';

    test('解析短信项', () {
      final items = parsePmInbox(html);
      expect(items.length, 1);
      final item = items.first;
      expect(item.id, '123');
      expect(item.name, '测试用户');
      expect(item.userId, '42');
      expect(item.title, '你好');
      expect(item.content, 'Re: 这是内容');
      expect(item.isNew, isTrue);
      expect(hasNewPm(items), isTrue);
      expect(hasNewPm(const []), isFalse);
    });
  });

  group('parsePmChat', () {
    test('解析相关短信线程', () {
      final data = parsePmChat('''
        <div class="pm-chat-title"><strong><a class="l" href="/user/sakura">樱</a></strong></div>
        <div class="pm-thread-filter">
          <a href="/pm/conversation/9.chii?thread=11">旧主题</a>
          <a href="/pm/conversation/9.chii?thread=22">新主题</a>
        </div>
        <div class="pm-message-list">
          <div class="pm-thread-label">新主题</div>
          <div class="pm-message">
            <a class="avatar" href="/user/sakura"><span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/l/a.jpg')"></span></a>
            <div class="pm-message-body">你好</div>
            <div class="pm-message-info"><small>2026-8-1</small></div>
          </div>
        </div>
        <input name="formhash" value="abc" />
      ''');
      expect(data.form.peerUserId, 'sakura');
      expect(data.form.peerUserName, '樱');
      expect(data.form.threads, hasLength(2));
      expect(data.form.threads.map((e) => e.$1), containsAll(['11', '22']));
      expect(data.list.first.threadTitle, '新主题');
      expect(data.list.first.threadId, '22');
    });
  });

  group('CollectionStats', () {
    test('fromJson 解析统计', () {
      const raw = {
        'anime': {
          'wish': 1,
          'collect': 2,
          'doing': 3,
          'on_hold': 4,
          'dropped': 5,
        },
        'book': {
          'wish': 10,
          'collect': 20,
          'doing': 30,
          'on_hold': 40,
          'dropped': 50,
        },
      };
      final stats = CollectionStats.fromJson(raw);
      expect(stats.count('anime', CollectionStatus.wish), 1);
      expect(stats.count('anime', CollectionStatus.collect), 2);
      expect(stats.total('anime'), 15);
      expect(stats.total('book'), 150);
      expect(stats.total('missing'), 0);
    });

    test('fromJson 解析旧版数组统计', () {
      final stats = CollectionStats.fromJson([
        {
          'name': '动画',
          'collects': [
            {
              'status': {'id': 1},
              'count': 8,
            },
            {
              'status': {'id': 3},
              'count': 4,
            },
          ],
        },
      ]);
      expect(stats.count('anime', CollectionStatus.wish), 8);
      expect(stats.count('anime', CollectionStatus.doing), 4);
    });
  });

  group('basicKatakanaToRomaji', () {
    test('基础片假名单音转换', () {
      expect(basicKatakanaToRomaji('リズム'), 'rizumu');
      expect(basicKatakanaToRomaji('ミラクル'), 'mirakuru');
      expect(basicKatakanaToRomaji('ガンダム'), 'gandamu');
    });
    test('非片假名原样保留', () {
      expect(basicKatakanaToRomaji('ABC'), 'ABC');
      expect(basicKatakanaToRomaji(''), '');
    });
  });

  group('replaceOriginUrl', () {
    test('编码 CN/JP/ID, DECODE 保持原文', () {
      final url = replaceOriginUrl(
        'https://x.test/?q=[CN]&jp=[JP]&id=[ID]&raw=[CN_DECODE]',
        cn: 'cowboy bebop',
        jp: 'カウボーイビバップ',
        id: 12,
        year: '1998',
      );
      expect(url, contains('q=cowboy%20bebop'));
      expect(url, contains('id=12'));
      expect(url, contains('raw=cowboy bebop'));
    });
  });

  group('originsForType', () {
    test('书籍走漫画+文库', () {
      final list = originsForType(kDefaultOrigins, 'book');
      expect(
        list.any((e) => e.name.contains('漫画') || e.uuid.startsWith('manga')),
        isTrue,
      );
      expect(list.any((e) => e.uuid.startsWith('wenku')), isTrue);
    });

    test('动画走 anime 默认源', () {
      final list = originsForType(kDefaultOrigins, 'anime');
      expect(list.map((e) => e.name), contains('AGE动漫'));
    });
  });

  group('parseUserHomeExtra', () {
    test('解析加入日期、同步率和最近活跃', () {
      const html = '''
<div class="nameSingle">
  <span class="tip">2020-1-2 加入</span>
  <span class="percent_text">66.6%</span>
  <small class="hot">完成了 12 个条目</small>
</div>
<div class="timeline">
  <small class="time">3小时前 · 看过</small>
</div>
''';
      final extra = parseUserHomeExtra(html);
      expect(extra.join, '2020-1-2 加入');
      expect(extra.percent, 66.6);
      expect(extra.hobby, '12');
      expect(extra.recent, contains('3小时前'));
    });
  });

  group('user Extra', () {
    test('DATA_ME 对齐原版不含本地管理备份设置', () {
      expect(kUserMenus.map((e) => e.$1).toList(), [
        '我的空间',
        '我的好友',
        '谁加我为好友',
        '我的人物',
        '我的目录',
        '我的日志',
        '我的词云',
        '我的时间线',
        '我的netaba.re',
      ]);
    });

    test('时光机工具栏更多对齐原版布局分页年份', () {
      expect(
        myCollectionMoreItems(
          list: true,
          pagination: true,
          showYear: true,
        ).map((e) => e.$2).toList(),
        ['布　局〔列表〕', '分页器〔开启〕', '设置'],
      );
      expect(
        myCollectionMoreItems(
          list: false,
          pagination: false,
          showYear: false,
        ).map((e) => e.$2).toList(),
        ['布　局〔网格〕', '分页器〔关闭〕', '年　份〔不显示〕', '设置'],
      );
    });

    test('时光机标签解析 #userTagList 一级文本', () {
      const html = '''
<ul id="userTagList">
  <li><a class="l" href="/anime/list/u/collect?tag=TV">TV<small>12</small></a></li>
  <li><a class="l" href="/anime/list/u/collect?tag=漫画改">漫画改<small>3</small></a></li>
</ul>
<div class="menu_inner"></div>
''';
      final tags = parseUserCollectionsTags(html);
      expect(tags.map((e) => e.tag).toList(), ['TV', '漫画改']);
      expect(tags.map((e) => e.count).toList(), [12, 3]);
      expect(userCollectionTagMenuItems(tags), ['重置', 'TV (12)', '漫画改 (3)']);
      expect(userCollectionTagMenuItems(tags, reset: false), [
        '全部',
        'TV (12)',
        '漫画改 (3)',
      ]);
      expect(parseUserCollectionTagSelect('重置'), '');
      expect(parseUserCollectionTagSelect('全部'), '');
      expect(parseUserCollectionTagSelect('TV (12)'), 'TV');
      expect(userCollectionTagLabel(''), '标签');
      expect(userCollectionTagLabel('TV'), 'TV');
    });

    test('时光机收藏 HTML 对齐原版 HTML_USER_COLLECTIONS', () {
      expect(
        htmlUserCollections('sakura', scope: 'anime', type: 'do', tag: 'TV'),
        'https://bgm.tv/anime/list/sakura/do?tag=TV&page=1',
      );
      expect(htmlCollectionStatus(1), 'wish');
      expect(htmlCollectionStatus(2), 'collect');
      expect(htmlCollectionStatus(3), 'do');
      expect(htmlCollectionStatus(4), 'on_hold');
      expect(htmlCollectionStatus(5), 'dropped');
    });

    test('时光机收藏 HTML 解析条目 tip 标签和时间', () {
      const html = '''
<ul id="browserItemList">
  <li id="item_8" class="item">
    <h3><a href="/subject/8" class="l">Code Geass</a><small class="grey">コードギアス</small></h3>
    <img class="cover" src="//lain.bgm.tv/pic/cover/c/x.jpg" />
    <p class="info tip">2006年10月6日 / TV</p>
    <div class="collectInfo">
      <span class="tip">标签: TV 机战</span>
      <span class="tip_j">2026-8-1</span>
    </div>
    <span class="starlight stars9"></span>
    <div class="text_main_even">好看</div>
  </li>
</ul>

<div id="columnSubjectBrowserB"></div>
<div class="page_inner"><span class="p_edge">( 1 / 3 )</span></div>
''';
      final page = parseUserCollections(html, subjectType: 'anime', status: 2);
      expect(page.items, hasLength(1));
      expect(page.items.first.subject.id, 8);
      expect(page.items.first.subject.nameCn, 'Code Geass');
      expect(page.items.first.subject.name, 'コードギアス');
      expect(page.items.first.comment, '好看');
      expect(page.items.first.tags, ['TV', '机战']);
      expect(page.items.first.updatedAt, '2026-8-1');
      expect(page.items.first.tip, contains('2006年10月6日'));
      expect(page.items.first.rate, 9);
      expect(page.pageTotal, 3);
    });

    test('空间更多文案对齐原版 MENU_DS', () {
      expect(zoneMoreItems(blocked: false).map((e) => e.$2).toList(), [
        '浏览器查看',
        '复制链接',
        '复制分享',
        '发短信',
        'TA的收藏',
        'TA的好友',
        '谁加TA为好友',
        'TA的人物',
        '加为好友',
        '绝交',
        '报告疑虑',
      ]);
      expect(
        zoneMoreItems(blocked: true).map((e) => e.$1),
        isNot(contains('block')),
      );
    });

    test('空间收藏概览解析 collects 分组', () {
      final sections = parseZoneCollectionsOverview([
        {
          'collects': [
            {
              'status': {'name': '在看'},
              'count': 3,
              'list': [
                {
                  'subject': {
                    'id': 8,
                    'name': 'コードギアス',
                    'name_cn': 'Code Geass',
                    'images': {'medium': '//lain.bgm.tv/pic/cover/c/x.jpg'},
                  },
                },
              ],
            },
            {
              'status': {'name': '想看'},
              'count': 1,
              'list': [
                {
                  'subject': {
                    'id': 12,
                    'name': 'CLANNAD',
                    'name_cn': '',
                    'images': {'common': 'https://lain.bgm.tv/c.jpg'},
                  },
                },
              ],
            },
          ],
        },
      ]);
      expect(sections.map((e) => e.status).toList(), [
        CollectionStatus.doing,
        CollectionStatus.wish,
      ]);
      expect(sections.first.title, '在看');
      expect(sections.first.count, 3);
      expect(sections.first.items.first.displayName, 'Code Geass');
      expect(sections.first.items.first.cover, startsWith('https://'));
      expect(sections.last.items.first.displayName, 'CLANNAD');
      expect(zoneCollectionMoreItems(collapse: true, alignCenter: false), [
        '自动折叠〔开〕',
        '标题居中〔关〕',
      ]);
    });

    test('好友顶栏菜单是浏览器查看和补充说明', () {
      expect(kFriendsMoreItems.map((e) => e.$2).toList(), ['浏览器查看', '补充说明']);
    });

    test('好友标题区分我和TA', () {
      expect(friendsTitle(rev: false, isMe: true), '我的好友');
      expect(friendsTitle(rev: true, isMe: true), '谁加我为好友');
      expect(friendsTitle(rev: false, isMe: false), 'TA的好友');
      expect(friendsTitle(rev: true, isMe: false), '谁加TA为好友');
    });
    test('我的好友长按菜单对齐原版 DATA_FRIEND', () {
      expect(friendMenuItems(rev: false).map((e) => e.$2).toList(), [
        '发短信',
        '解除好友',
      ]);
      expect(friendMenuItems(rev: true).map((e) => e.$2).toList(), ['移除对我的关注']);
    });
    test('好友过滤匹配用户名和 ID', () {
      const list = [
        Friend(userId: 'sai', userName: '神楽坂霧人'),
        Friend(userId: '123', userName: 'sakura'),
      ];
      expect(filterFriends(list, '').map((e) => e.userId), ['sai', '123']);
      expect(filterFriends(list, ' SAKURA ').map((e) => e.userId), ['123']);
      expect(filterFriends(list, 'sai').map((e) => e.userName), ['神楽坂霧人']);
      expect(filterFriends(list, 'nobody'), isEmpty);
    });
    test('好友活跃度按原版阈值分组', () {
      const list = [
        Friend(userId: 'a', userName: 'A'),
        Friend(userId: 'b', userName: 'B'),
        Friend(userId: 'c', userName: 'C'),
      ];
      const now = 1_700_000_000;
      final groups = groupFriendsByActive(list, {
        'a': now - 60,
        'b': now - 40000,
        'c': 0,
      }, now);
      expect(groups['一小时内'], ['a']);
      expect(groups['一天内'], ['b']);
      expect(groups['三天内'], isEmpty);
      final entries = buildFriendList(
        friends: list,
        filter: '',
        groups: groups,
      );
      expect(entries.whereType<FriendHeaderEntry>().map((e) => e.title), [
        '一小时内',
        '一天内',
        '未知',
      ]);
      expect(entries.whereType<FriendItemEntry>().map((e) => e.friend.userId), [
        'a',
        'b',
      ]);
      expect(
        friendsActiveRefreshIds(list, {'a': now - 60}, full: true, nowSec: now),
        ['a', 'b', 'c'],
      );
      expect(
        friendsActiveRefreshIds(
          list,
          {'a': now - 60, 'b': now - 200000, 'c': 0},
          full: false,
          nowSec: now,
        ),
        ['b', 'c'],
      );
      expect(
        parseUserActiveCreatedAt([
          {'createdAt': 8},
        ]),
        8,
      );
      expect(parseUserActiveCreatedAt([]), 0);
    });

    test('时间线标题带用户名', () {
      expect(userTimelineTitle('sakura'), 'sakura的时间线');
      expect(userTimelineTitle(''), '时间线');
      expect(userTimelineTitle(null), '时间线');
    });

    test('服务可用性选项对齐原版 SETTING_SERVER_STATUS', () {
      expect(kServerStatusNotifyItems.map((e) => e.$2).toList(), [
        '不显示',
        '降级时',
        '中断时',
      ]);
    });

    test('自定义源头顶栏只留说明', () {
      expect(kOriginMoreItems.map((e) => e.$2).toList(), ['说明']);
    });

    test('网络探针标题对齐原版', () {
      expect(kServerStatusTitle, '网络探针');
    });

    test('自定义跳转顶栏只留说明', () {
      expect(kActionsMoreItems.map((e) => e.$2).toList(), ['说明']);
    });
    test('自定义跳转标题优先用条目标题', () {
      expect(actionsTitle(null), '自定义跳转');
      expect(actionsTitle(''), '自定义跳转');
      expect(actionsTitle(' CLANNAD '), 'CLANNAD');
    });

    test('赞助和备份顶栏只留说明', () {
      expect(kSponsorMoreItems.map((e) => e.$2).toList(), ['说明']);
      expect(kBackupMoreItems.map((e) => e.$2).toList(), ['说明']);
    });

    test('照片墙列数对齐原版 2-5', () {
      expect(kMilestoneColumns, ['2', '3', '4', '5']);
    });

    test('短信详情标题是全部或线程名加条数', () {
      expect(pmHeaderTitle(compose: true), '短信');
      expect(pmHeaderTitle(compose: false), '全部');
      expect(
        pmHeaderTitle(compose: false, threadTitle: 'Re', msgCount: 3),
        'Re (3)',
      );
      expect(pmHeaderTitleSize('全部'), 16);
      expect(pmHeaderTitleSize('这是一条很长的短信标题'), 15);
      expect(pmShowThreadCount(2), isFalse);
      expect(pmShowThreadCount(3), isTrue);
      expect(pmShowScrollNav(threadCount: 1, messageCount: 3), isFalse);
      expect(pmShowScrollNav(threadCount: 2, messageCount: 1), isTrue);
      expect(pmPrevThreadIndex(labelIndexes: [0, 5, 9], currentIndex: 6), 5);
      expect(pmNextThreadIndex(labelIndexes: [0, 5, 9], currentIndex: 6), 9);
      expect(pmPrevThreadIndex(labelIndexes: [0], currentIndex: 0), isNull);
    });

    test('关于客户端标题对齐原版 qiafan', () {
      expect(kQiafanTitle, '关于客户端');
    });
  });
}
