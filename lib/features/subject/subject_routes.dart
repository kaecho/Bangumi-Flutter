import 'package:go_router/go_router.dart';

import 'catalogs_screen.dart';
import 'characters_screen.dart';
import 'ep_comments_screen.dart';
import 'episodes_screen.dart';
import 'info_screen.dart';
import 'link_screen.dart';
import 'mono_screen.dart';
import 'mono_subjects_screen.dart';
import 'overview_screen.dart';
import 'persons_screen.dart';
import 'preview_screen.dart';
import 'rating_screen.dart';
import 'subject_comments_screen.dart';
import 'subject_screen.dart';
import 'tag_screen.dart';
import 'typerank_screen.dart';
import 'voices_screen.dart';
import 'wiki_screen.dart';
import 'works_screen.dart';

/// 条目域路由 (条目详情及其子页面)
final List<GoRoute> subjectRoutes = [
  // 条目详情
  GoRoute(
    path: '/subject/:id',
    builder: (_, state) => SubjectScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 条目信息
  GoRoute(
    path: '/subject/:id/info',
    builder: (_, state) => SubjectInfoScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 章节列表
  GoRoute(
    path: '/subject/:id/episodes',
    builder: (_, state) => EpisodesScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 章节吐槽箱
  GoRoute(
    path: '/subject/:id/ep/:epId/comments',
    builder: (_, state) => EpCommentsScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      epId: int.tryParse(state.pathParameters['epId'] ?? '') ?? 0,
    ),
  ),
  // 角色列表
  GoRoute(
    path: '/subject/:id/characters',
    builder: (_, state) => CharactersScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 制作人员
  GoRoute(
    path: '/subject/:id/persons',
    builder: (_, state) => PersonsScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 评分分布
  GoRoute(
    path: '/subject/:id/rating',
    builder: (_, state) => RatingScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 番剧截屏预览
  GoRoute(
    path: '/subject/:id/preview',
    builder: (_, state) => PreviewScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 条目标签
  GoRoute(
    path: '/subject/:id/tag',
    builder: (_, state) => SubjectTagScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 分类排行
  GoRoute(
    path: '/subject/:id/typerank',
    builder: (_, state) => SubjectTypeRankScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      tag: state.uri.queryParameters['tag'] ?? '',
      type: state.uri.queryParameters['type'] ?? 'anime',
    ),
  ),
  // 作品 (人物)
  GoRoute(
    path: '/subject/:id/works',
    builder: (_, state) => WorksScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 声优
  GoRoute(
    path: '/subject/:id/voices',
    builder: (_, state) => VoicesScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 关联条目
  GoRoute(
    path: '/subject/:id/link',
    builder: (_, state) => LinkScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 包含该条目的目录
  GoRoute(
    path: '/subject/:id/catalogs',
    builder: (_, state) => CatalogsScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 条目概览 (书籍/音乐)
  GoRoute(
    path: '/subject/:id/overview',
    builder: (_, state) => OverviewScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 维基编辑历史
  GoRoute(
    path: '/subject/:id/wiki',
    builder: (_, state) => WikiScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 条目吐槽箱
  GoRoute(
    path: '/subject/:id/comments',
    builder: (_, state) => SubjectCommentsScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 角色 / 人物详情
  GoRoute(
    path: '/mono/character/:id',
    builder: (_, state) => MonoScreen(
      type: 'character',
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  GoRoute(
    path: '/mono/person/:id',
    builder: (_, state) => MonoScreen(
      type: 'person',
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  // 角色 / 人物全部作品
  GoRoute(
    path: '/mono/character/:id/subjects',
    builder: (_, state) => MonoSubjectsScreen(
      type: 'character',
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  GoRoute(
    path: '/mono/person/:id/subjects',
    builder: (_, state) => MonoSubjectsScreen(
      type: 'person',
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
];
