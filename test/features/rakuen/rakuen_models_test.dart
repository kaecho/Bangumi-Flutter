import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/rakuen/html_parse.dart';
import 'package:bangumi/features/rakuen/rakuen_models.dart';
import 'package:bangumi/features/rakuen/rakuen_settings.dart';
import 'package:bangumi/features/rakuen/widgets/fixed_textarea.dart';
import 'package:bangumi/shared/widgets/bgm_html.dart';
import 'package:bangumi/features/rakuen/blog_screen.dart';
import 'package:bangumi/features/rakuen/group_screen.dart';
import 'package:bangumi/features/rakuen/rakuen_screen.dart';
import 'package:bangumi/features/rakuen/topic_screen.dart';
import 'package:bangumi/features/rakuen/widgets/topic_row.dart';
import 'package:bangumi/features/rakuen/reviews_screen.dart';
import 'package:bangumi/features/rakuen/mine_screen.dart';
import 'package:bangumi/shared/models/group.dart';


void main() {
  group('topicIdFromHref', () {
    test('映射 rakuen/topic/group', () {
      expect(topicIdFromHref('/rakuen/topic/group/461956'), 'group/461956');
    });
    test('映射 group/topic', () {
      expect(topicIdFromHref('/group/topic/350677'), 'group/350677');
    });
    test('映射 subject/topic', () {
      expect(topicIdFromHref('/subject/topic/3469'), 'subject/3469');
    });
    test('映射 blog', () {
      expect(topicIdFromHref('/blog/378305'), 'blog/378305');
    });
    test('映射 ep', () {
      expect(topicIdFromHref('/ep/271319'), 'ep/271319');
    });
  });

  group('parseTopicPage', () {
    test('解析主楼 + 楼层 + 子回复', () {
      const html = '''
<html><body>
<div id="pageHeader"><h1><span><a class="avatar" href="/group/dev"><img class="avatar" src="//lain.bgm.tv/pic/icon/s/000/00/00/1.jpg" />番组开发</a> » <a href="/group/dev/forum">讨论</a></span><br />测试标题</h1></div>

<div id="post_1" class="postTopic">
  <div class="post_actions re_info"><div class="action"><small>#1 - 2024-1-1 10:00</small></div></div>
  <a href="/user/100" class="avatar"><span class="avatarNeue avatarSize48" style="background-image:url('//lain.bgm.tv/pic/a.jpg')"></span></a>
  <div class="inner"><strong><a href="/user/100" class="l">作者</a></strong><span class="sign tip_j">(签名)</span>
  <div class="topic_content"><p>主楼内容</p></div></div>
</div>
<form id="ReplyForm" action="/group/topic/1/new_reply">
  <input type="hidden" name="formhash" value="abc123" />
  <input type="hidden" name="lastview" value="1700000000" />
</form>
<div id="comment_list">
  <div id="post_2" class="row row_reply">
    <div class="post_actions re_info"><div class="action"><small><a href="#post_2">#2</a> - 2024-1-2 11:00</small>
      <a class="icon" onclick="subReply('group', 1, 2, 0, 100, 200, 0)"></a>
    </div></div>
    <a href="/user/200" class="avatar"><span class="avatarNeue avatarSize40" style="background-image:url('//lain.bgm.tv/pic/b.jpg')"></span></a>
    <div class="inner"><span class="userInfo"><strong><a href="/user/200" class="l">回复者</a></strong><span class="sign tip_j">(回)</span></span>
      <div class="reply_content"><div class="message">楼层内容</div></div>
      <div class="topic_sub_reply">
        <div id="post_3" class="sub_reply_bg">
          <div class="post_actions re_info"><div class="action"><small><a href="#post_3">#2-1</a> - 2024-1-3 12:00</small></div></div>
          <a href="/user/300" class="avatar"><span class="avatarNeue avatarSize32" style="background-image:url('//lain.bgm.tv/pic/c.jpg')"></span></a>
          <div class="inner"><strong class="userName"><a href="/user/300" class="l">子回复者</a></strong>
            <div class="cmt_sub_content">子回复内容</div></div>
        </div>
      </div>
    </div>
  </div>
</div>
</body></html>''';
      final data = parseTopicPage(html);
      expect(data.title, '测试标题');
      expect(data.group, '番组开发');
      expect(data.groupHref, '/group/dev');
      expect(data.groupThumb, contains('1.jpg'));

      expect(data.userName, '作者');
      expect(data.userId, '100');
      expect(data.time, '2024-1-1 10:00');
      expect(data.contentHtml, contains('主楼内容'));
      expect(data.formhash, 'abc123');
      expect(data.lastview, '1700000000');
      expect(data.floors, hasLength(1));

      final floor = data.floors.first;
      expect(floor.userName, '回复者');
      expect(floor.userId, '200');
      expect(floor.floor, contains('#2'));
      expect(floor.replySub, contains("subReply('group'"));
      expect(floor.messageHtml, contains('楼层内容'));
      expect(floor.subReplies, hasLength(1));
      expect(floor.subReplies.first.userName, '子回复者');
      expect(floor.subReplies.first.messageHtml, contains('子回复内容'));
      expect(floor.subReplies.first.floor, '#2-1');
    });
  });

  group('parseGroupForum', () {
    test('解析 tr.topic 表格行', () {
      const html = '''
<html><body>
<table><tbody>
<tr class="topic even" data-item-user="xdcedar">
  <td class="subject"><a href="/group/topic/352335" title="[组件] 楼层回复美化" class="l">[组件] 楼层回复美化</a></td>
  <td class="author"><a href="/user/xdcedar" class="l">Cedar</a></td>
  <td class="posts">28</td>
  <td class="lastpost"><small class="time">2026-8-11 15:16</small></td>
</tr>
</tbody></table>
</body></html>''';
      final items = parseGroupForum(html);
      expect(items, hasLength(1));
      expect(items.first.topicId, 'group/352335');
      expect(items.first.title, '[组件] 楼层回复美化');
      expect(items.first.userName, 'Cedar');
      expect(items.first.userId, '');
      expect(items.first.replyCount, 28);
      expect(items.first.time, '2026-8-11 15:16');
    });
    test('解析条目讨论版 /subject/topic 行', () {
      const html = '''
<html><body>
<table><tbody>
<tr class="topic even">
  <td class="subject"><a href="/subject/topic/12345" title="讨论标题" class="l">讨论标题</a></td>
  <td class="author"><a href="/user/42" class="l">Alice</a></td>
  <td class="posts">7</td>
  <td class="lastpost"><small class="time">2026-8-12 10:00</small></td>
</tr>
</tbody></table>
</body></html>''';
      final items = parseGroupForum(html);
      expect(items, hasLength(1));
      expect(items.first.topicId, 'subject/12345');
      expect(items.first.title, '讨论标题');
      expect(items.first.userId, '42');
      expect(items.first.replyCount, 7);
    });
  });

  group('parseGroupHome', () {
    test('解析加入与退出链接', () {
      const html = '''
<html><body>
<h1>番组开发</h1>
<div id="groupJoinAction"><a class="chiiBtn" href="/group/dev/join?gh=abc">加入</a></div>
</body></html>''';
      final info = parseGroupHome(html);
      expect(info.title, '番组开发');
      expect(info.joinUrl, contains('/join?'));
      expect(info.joined, isFalse);
      final quit = parseGroupHome('''
<html><body>
<h1>番组开发</h1>
<div id="groupJoinAction"><a class="chiiBtn" href="/group/dev/bye?gh=abc">退出</a></div>
</body></html>''');
      expect(quit.byeUrl, contains('/bye?'));
      expect(quit.joined, isTrue);
    });
  });

  group('RakuenSettingsState', () {
    test('toJson/fromJson 往返', () {
      const state = RakuenSettingsState(
        blockUsers: ['a', 'b'],
        blockGroups: ['group1'],
        blockKeywords: ['关键词'],
        blockDefaultUser: true,
        floorStyle: 'C',
        quote: false,
        subExpand: '2',
        autoLoadImage: '0',
      );
      final restored = RakuenSettingsState.fromJson(state.toJson());
      expect(restored.blockUsers, ['a', 'b']);
      expect(restored.blockGroups, ['group1']);
      expect(restored.blockKeywords, ['关键词']);
      expect(restored.blockDefaultUser, isTrue);
      expect(restored.floorStyle, 'C');
      expect(restored.quote, isFalse);
      expect(restored.subExpand, '2');
      expect(restored.autoLoadImage, '0');
      expect(restored.loadImages, isFalse);
    });
  });

  group('Review', () {
    test('fromJson', () {
      final review = Review.fromJson({
        'id': 100,
        'title': '评论标题',
        'user_id': 42,
        'user': {
          'id': 42,
          'username': 'u42',
          'nickname': '昵称',
          'avatar': {'large': 'l', 'medium': 'm', 'small': 's'},
        },
        'created_at': '2024-01-01 10:00',
        'replies': 5,
      });
      expect(review.id, 100);
      expect(review.title, '评论标题');
      expect(review.user?.displayName, '昵称');
      expect(review.replies, 5);
    });
  });

  group('HistoryItem', () {
    test('toJson/fromJson 往返', () {
      const item = HistoryItem(
        topicId: 'group/461956',
        title: '测试主题',
        group: '番组开发',
        replies: 3,
        time: 1700000000,
      );
      final restored = HistoryItem.fromJson(item.toJson());
      expect(restored.topicId, 'group/461956');
      expect(restored.title, '测试主题');
      expect(restored.replies, 3);
      expect(restored.time, 1700000000);
    });
  });

  group('BgmHtml', () {
    testWidgets('渲染纯文本 HTML', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BgmHtml(data: '<p>你好 <b>Bangumi</b></p>')),
        ),
      );
      expect(find.textContaining('你好'), findsOneWidget);
      expect(find.textContaining('Bangumi'), findsOneWidget);
    });

    testWidgets('showImages=false 时移除 img', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BgmHtml(
              data: '<p>文字<img src="http://x/a.jpg"></p>',
              showImages: false,
            ),
          ),
        ),
      );
      expect(find.textContaining('文字'), findsOneWidget);
    });
  });

  group('insertBbcode / quoteReply', () {
    test('选中文字包 BBCode', () {
      final r = insertBbcode(
        'hello',
        const TextSelection(baseOffset: 0, extentOffset: 5),
        r'[b]$TEXT$[/b]',
      );
      expect(r.value, '[b]hello[/b]');
      expect(r.cursor, 8);
    });

    test('引用去掉旧 quote 再截断', () {
      final text = quoteReplyContent(
        userName: '甲',
        messageHtml: '<div class="quote"><q>旧</q></div>你好世界',
        content: '回复',
      );
      expect(text, contains('[quote][b]甲[/b] 说: 你好世界[/quote]'));
      expect(text, endsWith('回复'));
    });

    test('解析 subReply onclick', () {
      final p = parseReplySub(
        "subReply('group', 468754, 4007985, 0, 859738, 1184949, 0)",
      );
      expect(p, isNotNull);
      expect(p!.type, 'group');
      expect(p.topicId, '468754');
      expect(p.related, '4007985');
      expect(p.postUid, '1184949');
    });
  });

  group('rakuen Extra', () {
    test('超展开顶栏菜单对齐原版 IconMore', () {
      expect(kRakuenMoreItems.map((e) => e.$2).toList(), [
        '小组搜索',
        '超展开设置',
        '添加新讨论',
      ]);
    });

    test('帖子顶栏含 id 行和举报', () {
      expect(topicMoreItems('group/1').map((e) => e.$2).toList(), [
        '帖子 · group/1',
        '网页版查看',
        '复制链接',
        '复制分享',
        '举报',
      ]);
    });

    test('日志顶栏是浏览器查看复制链接复制分享', () {
      expect(kBlogMoreItems.map((e) => e.$2).toList(), [
        '浏览器查看',
        '复制链接',
        '复制分享',
      ]);
    });

    test('小组顶栏加入退出随状态变, 时间格式可切', () {
      expect(
        groupMoreItems(
          joined: false,
          canJoin: true,
          canQuit: false,
          lastDate: true,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '小组成员', '加入小组', '时间格式〔最近〕'],
      );
      expect(
        groupMoreItems(
          joined: true,
          canJoin: false,
          canQuit: true,
          lastDate: false,
        ).map((e) => e.$2).toList(),
        ['浏览器查看', '小组成员', '退出小组', '时间格式〔日期〕'],
      );
    });

    test('已是绝对日期的小组时间不再二次格式化', () {
      expect(
        formatRakuenTopicTime('2024-1-1 10:00', lastDate: true),
        '2024-1-1 10:00',
      );
      expect(formatRakuenTopicTime('', lastDate: true), '');
    });

    test('影评标题带条目名, 路径带 name', () {
      expect(reviewsTitle('CLANNAD'), 'CLANNAD的影评');
      expect(reviewsTitle(''), '影评');
      expect(reviewsPath(8), '/rakuen/reviews/8');
      expect(reviewsPath(8, name: 'CLANNAD'), '/rakuen/reviews/8?name=CLANNAD');
    });

    test('我的小组 Extra 是我的和全部, 可按名过滤', () {
      expect(kMineGroupTypes.map((e) => e.$2).toList(), ['我的', '全部']);
      const list = [
        MyGroup(id: 'a', cover: '', name: '新番乐园'),
        MyGroup(id: 'b', cover: '', name: '邦纪'),
      ];
      expect(filterMineGroups(list, '新番').map((e) => e.id), ['a']);
      expect(filterMineGroups(list, 'B').map((e) => e.id), ['b']);
      expect(filterMineGroups(list, ''), hasLength(2));
    });

    test('日志吐槽标题计楼层加子回复', () {
      expect(commentSectionTitle(0), '吐槽');
      expect(commentSectionTitle(3), '吐槽 3');
      expect(blogFavorTopicId(8), 'blog/8');
      expect(commentFloorCount(const []), 0);
    });

    test('电波提醒连续相同项合并显示 xN', () {
      const a = Notify(
        title: '回了你',
        content: '嗨',
        avatar: 'a.png',
        url: '/t/1',
      );
      const b = Notify(
        title: '回了你',
        content: '嗨',
        avatar: 'a.png',
        url: '/t/1',
      );
      const c = Notify(title: '另条', content: '嗨', avatar: 'a.png', url: '/t/2');
      final merged = mergeNotifyItems([a, b, c]);
      expect(merged, hasLength(2));
      expect(merged.first.badge, 'x2');
      expect(merged.last.badge, '');
    });
  });
}
