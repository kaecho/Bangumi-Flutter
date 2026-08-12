import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';

/// 用户协议 (移植自原项目 screens/rakuen/ugc-agree)
/// 路由: /rakuen/ugc-agree
class UgcAgreeScreen extends StatelessWidget {
  const UgcAgreeScreen({super.key});

  static const _title = 'Bangumi 番组计划';

  @override
  Widget build(BuildContext context) {
    const sectionStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.6);
    const bodyStyle = TextStyle(fontSize: 13.5, height: 1.7);

    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '生命有限，$_title 是一个纯粹的ACG网络，只要明确这一点，你完全可以跳过以下内容的阅读',
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          const Text('/ Chobits 鼓励', style: sectionStyle),
          const SizedBox(height: 8),
          for (final item in const [
            '鼓励分享、互助和开放；',
            '鼓励宽容和理性地对待不同的看法、喜好和意见；',
            '鼓励尊重他人的隐私和个人空间；',
            '鼓励转载注明原作者及来源；',
            '鼓励精彩原创内容；',
            '鼓励明确、及时的资源分享和点评；',
            '鼓励有始有终的自发福利活动。',
          ])
            Text('· $item', style: bodyStyle),
          const SizedBox(height: 16),
          const Text('/ $_title 不提倡', style: sectionStyle),
          const SizedBox(height: 8),
          for (final item in const [
            '针对种族、国家、民族、宗教、性别、年龄、地缘、性取向、生理特征的歧视和仇恨言论；',
            '不雅词句、人身攻击、故意骚扰和恶意使用；',
            '色情、激进时政、意识形态方面的话题；',
            '使用脑残体等妨碍视觉与心灵的文字；',
            '无授权转载，盗图、盗链、盗资源；',
            '不提倡情绪激动而心灵枯槁的内容；',
            '不提倡转载过期变质内容；',
            '不提倡不知所谓的长篇大论；',
            '不提倡调查贴、投票贴、签名贴。',
          ])
            Text('· $item', style: bodyStyle),
          const SizedBox(height: 16),
          const Text('/ $_title 禁止', style: sectionStyle),
          const SizedBox(height: 8),
          Text(
            '以下行为视情况直接删除、锁定或删除ID、批量删除而不予通知；',
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final item in const [
            '违反中国或 $_title 成员所在地法律法规的行为和内容（政策法规）；',
            '威胁他人或 $_title 成员自身的人身安全、法律安全的行为；',
            '对网站的运营安全有潜在威胁的内容。',
          ])
            Text('· $item', style: bodyStyle),
          const SizedBox(height: 24),
          Text(
            '指导原则的编写参考了豆瓣以及XQ网站，最后更新日期为：2008-08-06 20:32',
            style: context.ds.meta,
          ),
        ],
      ),
    );
  }
}
