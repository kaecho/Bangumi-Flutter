import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/user/origin_utils.dart';
import 'package:bangumi/features/user/user_models.dart';
import 'package:bangumi/shared/models/collection.dart';

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
}
