import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/rakuen/html_parse.dart';
import 'package:bangumi/features/rakuen/rakuen_models.dart';
import 'package:bangumi/features/rakuen/rakuen_settings.dart';
import 'package:bangumi/shared/widgets/bgm_html.dart';

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
<div id="pageHeader"><h1><a href="/group/dev">番组开发</a> » <a href="/group/dev/forum">讨论</a><br />测试标题</h1></div>
<div id="post_1" class="postTopic">
  <div class="post_actions re_info"><div class="action"><small>#1 - 2024-1-1 10:00</small></div></div>
  <a href="/user/100" class="avatar"><span class="avatarNeue avatarSize48" style="background-image:url('//lain.bgm.tv/pic/a.jpg')"></span></a>
  <div class="inner"><strong><a href="/user/100" class="l">作者</a></strong><span class="sign tip_j">(签名)</span>
  <div class="topic_content"><p>主楼内容</p></div></div>
</div>
<div id="comment_list">
  <div id="post_2" class="row row_reply">
    <div class="post_actions re_info"><div class="action"><small><a href="#post_2">#2</a> - 2024-1-2 11:00</small></div></div>
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
      expect(data.userName, '作者');
      expect(data.userId, '100');
      expect(data.time, '2024-1-1 10:00');
      expect(data.contentHtml, contains('主楼内容'));
      expect(data.floors, hasLength(1));

      final floor = data.floors.first;
      expect(floor.userName, '回复者');
      expect(floor.userId, '200');
      expect(floor.floor, contains('#2'));
      expect(floor.messageHtml, contains('楼层内容'));
      expect(floor.subReplies, hasLength(1));
      expect(floor.subReplies.first.userName, '子回复者');
      expect(floor.subReplies.first.messageHtml, contains('子回复内容'));
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
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BgmHtml(data: '<p>你好 <b>Bangumi</b></p>')),
      ));
      expect(find.textContaining('你好'), findsOneWidget);
      expect(find.textContaining('Bangumi'), findsOneWidget);
    });

    testWidgets('showImages=false 时移除 img', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BgmHtml(data: '<p>文字<img src="http://x/a.jpg"></p>', showImages: false)),
      ));
      expect(find.textContaining('文字'), findsOneWidget);
    });
  });
}
