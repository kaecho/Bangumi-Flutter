import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/discovery/widgets/discovery_html.dart';

void main() {
  group('parseCatalogList', () {
    test('解析目录行 (封面/标题/作者/类型计数/更新时间)', () {
      const html = '''
<html><body>
<ul>
<li id="item_17538" class="clearit tml_item index-item">
  <span class="avatar"><a href="/user/144872" class="avatar"><span class="avatarNeue avatarReSize40 ll" style="background-image:url('//lain.bgm.tv/pic/user/l/000/14/48/144872.jpg')"></span></a></span>
  <span class="info clearit">
    <div class="clearit">
      <span class="stats tip rr"><span class="ico_subject_type num subject_type_2 ll"><span class="ico ico_2"></span><span class="num">216</span></span></span>
      <a href="/index/17538" class="l"><h3>&ldquo;实用&rdquo;的里番</h3></a>
    </div>
    <span class="time tip_i">
      <a href="/user/144872" class="l">无颜之月</a> ·
      创建 <span class="tip_j">2014-9-7 03:14</span> ·
      更新 <span class="tip_j">2022-4-25 12:45</span>
    </span>
    <span class="desc">如果不是什么想把里番全部看完的</span>
  </span>
</li>
</ul>
</body></html>
''';
      final rows = parseCatalogList(html);
      expect(rows.length, 1);
      final row = rows.first;
      expect(row.id, 17538);
      expect(row.title, '“实用”的里番');
      expect(row.desc, '如果不是什么想把里番全部看完的');
      expect(row.userId, 144872);
      expect(row.username, '无颜之月');
      expect(row.avatar, startsWith('https://lain.bgm.tv/'));
      expect(row.createdAt, '2014-9-7 03:14');
      expect(row.updatedAt, '2022-4-25 12:45');
      expect(row.total, 216);
      expect(row.anime, 216);
    });

    test('无目录返回空列表', () {
      expect(parseCatalogList('<html><body>空</body></html>'), isEmpty);
    });

    test('total 为 0 的目录仍被解析 (UI 层过滤)', () {
      const html = '''
<html><body>
<li id="item_1" class="clearit tml_item index-item">
  <span class="info clearit">
    <a href="/index/1" class="l"><h3>空目录</h3></a>
    <span class="time tip_i"><a href="/user/1" class="l">用户</a> ·
      创建 <span class="tip_j">2020-1-1 00:00</span> ·
      更新 <span class="tip_j">2020-1-2 00:00</span>
    </span>
  </span>
</li>
</body></html>
''';
      final rows = parseCatalogList(html);
      expect(rows.length, 1);
      expect(rows.first.total, 0);
    });
  });
}