import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';

/// 社区项目 (与原项目 ds.ts 一致)
class CommunityProject {
  final String title;
  final String url; // 空 = 应用内页面
  final String path; // 应用内路由路径 (VIB / BiWeekly)
  final String topicUrl;
  final String name;
  final String userId;

  const CommunityProject({
    required this.title,
    this.url = '',
    this.path = '',
    this.topicUrl = '',
    this.name = '',
    this.userId = '',
  });
}

bool communityTopicIsPost(String topicUrl) =>
    topicUrl.contains('/group/topic/');

String communityTopicKind(String topicUrl) =>
    communityTopicIsPost(topicUrl) ? '讨论' : '小组';

String fillCommunityUserId(String url, String userId) {
  if (!url.contains('[USER_ID]')) return url;
  return url.replaceAll('[USER_ID]', userId);
}

const kCommunityProjects = [
  CommunityProject(
    title: '2025 社区年度报告',
    url: 'https://bgm.ry.mk/report2025/?user=[USER_ID]',
    topicUrl: 'https://bgm.tv/group/topic/445853',
    name: '綿飴',
    userId: 'wataame',
  ),
  CommunityProject(
    title: '2025 年度动画报告',
    url: 'https://report.mikuorz.top',
    topicUrl: 'https://bgm.tv/group/topic/446062',
    name: 'Mikuorz',
    userId: 'pereza',
  ),
  CommunityProject(
    title: '2025 年度书籍报告',
    url: 'https://tongluoxia.tosuto.site',
    topicUrl: 'https://bgm.tv/group/topic/446395',
    name: '童洛夏',
    userId: 'tongluoxia',
  ),
  CommunityProject(
    title: '巡礼地图',
    url: 'https://www.anitabi.cn/map',
    topicUrl: 'https://bgm.tv/group/topic/376643',
    name: '卜卜口',
    userId: 'itorr',
  ),
  CommunityProject(
    title: 'Netabare',
    url: 'https://netaba.re',
    topicUrl: 'https://bgm.tv/group/topic/346147',
    name: '若卡',
    userId: 'ruocaled',
  ),
  CommunityProject(
    title: '班谷米排名大王',
    url: 'https://bgmtier.sakuga.org',
    topicUrl: 'https://bgm.tv/group/topic/447315',
    name: 'ANNA',
    userId: 'annblack',
  ),
  CommunityProject(
    title: 'VIB 数据月刊',
    path: '/vib',
    topicUrl: 'https://bgm.tv/group/qpz',
    name: 'Jirehlov',
    userId: 'jirehlov',
  ),
  CommunityProject(
    title: 'BMO:bmoji 合成大表情',
    url: 'https://bgm.tv/js/lib/bmo/gen_bmo.html',
    topicUrl: 'https://bgm.tv/group/bmoji',
    name: '五行行行行行啊',
    userId: '572805',
  ),
  CommunityProject(
    title: 'Bangumi 半月刊',
    path: '/bi-weekly',
    topicUrl: 'https://bgm.tv/group/biweekly',
    name: '他说nil没法调用IsNil',
    userId: 'neutrinoliu',
  ),
];

/// 社区项目 (静态列表, 与原项目一致: 无网络请求)
class DiscoveryUsersScreen extends ConsumerWidget {
  const DiscoveryUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserProvider)?.username ?? '';
    return Scaffold(
      appBar: const BgmAppBar(title: '社区项目', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final project in kCommunityProjects)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (project.path.isNotEmpty) {
                          context.push(project.path);
                          return;
                        }
                        openExternalUrl(fillCommunityUserId(project.url, myId));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project.title, style: context.ds.bodyStrong),
                          const SizedBox(height: 4),
                          Text(
                            '${project.name}@${project.userId}',
                            style: context.ds.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final url = project.topicUrl;
                      if (url.isEmpty) return;
                      if (communityTopicIsPost(url)) {
                        final id = int.tryParse(url.split('/').last);
                        if (id != null) {
                          context.push('/rakuen/topic/group/$id');
                          return;
                        }
                      }
                      final name = url.split('/').last;
                      if (name.isNotEmpty) {
                        context.push('/rakuen/group/$name');
                      }
                    },
                    child: Text(
                      communityTopicKind(project.topicUrl),
                      style: context.ds.caption,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '不定期收录一些班友开发的社区项目（非官方）',
              textAlign: TextAlign.center,
              style: context.ds.meta,
            ),
          ),
        ],
      ),
    );
  }
}
