import 'package:go_router/go_router.dart';

import 'adv_screen.dart';
import 'anime_screen.dart';
import 'anitama_screen.dart';
import 'award_screen.dart';
import 'biweekly_screen.dart';
import 'blog_screen.dart';
import 'browser_screen.dart';
import 'calendar_screen.dart';
import 'catalog_detail_screen.dart';
import 'catalog_screen.dart';
import 'channel_screen.dart';
import 'character_screen.dart';
import 'dollars_screen.dart';
import 'game_screen.dart';
import 'group_screen.dart';
import 'hentai_screen.dart';
import 'like_screen.dart';
import 'manga_screen.dart';
import 'nsfw_screen.dart';
import 'pic_screen.dart';
import 'rank_screen.dart';
import 'recommend_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'staff_screen.dart';
import 'tag_subjects_screen.dart';
import 'tags_screen.dart';
import 'typerank_screen.dart';
import 'users_screen.dart';
import 'vib_screen.dart';
import 'wiki_screen.dart';
import 'wordcloud_screen.dart';
import 'yearbook_screen.dart';

/// 发现域路由 (发现页子页面)
final List<GoRoute> discoveryRoutes = [
  GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
  GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
  GoRoute(path: '/rank', builder: (_, _) => const RankScreen()),
  GoRoute(path: '/anime', builder: (_, _) => const AnimeScreen()),
  GoRoute(path: '/staff', builder: (_, _) => const StaffScreen()),
  GoRoute(path: '/catalog', builder: (_, _) => const CatalogScreen()),
  GoRoute(
    path: '/catalog/:id',
    builder: (_, state) => CatalogDetailScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  GoRoute(path: '/yearbook', builder: (_, _) => const YearbookScreen()),
  GoRoute(path: '/tags', builder: (_, _) => const TagsScreen()),
  GoRoute(
    path: '/tags/:type/:tag',
    builder: (_, state) => TagSubjectsScreen(
      type: state.pathParameters['type'] ?? 'anime',
      tag: Uri.decodeComponent(state.pathParameters['tag'] ?? ''),
    ),
  ),
  GoRoute(path: '/blogs', builder: (_, _) => const BlogScreen()),
  GoRoute(path: '/groups', builder: (_, _) => const GroupScreen()),
  GoRoute(path: '/series', builder: (_, _) => const SeriesScreen()),
  GoRoute(path: '/recommend', builder: (_, _) => const RecommendScreen()),
  GoRoute(path: '/like', builder: (_, _) => const LikeScreen()),
  GoRoute(path: '/pic', builder: (_, _) => const PicScreen()),
  GoRoute(path: '/wiki', builder: (_, _) => const WikiScreen()),
  GoRoute(path: '/channel', builder: (_, _) => const ChannelScreen()),
  GoRoute(path: '/vib', builder: (_, _) => const VibScreen()),
  GoRoute(path: '/typerank', builder: (_, _) => const TypeRankScreen()),
  GoRoute(
    path: '/award/:year',
    builder: (_, state) => AwardScreen(
      year: int.tryParse(state.pathParameters['year'] ?? '') ?? DateTime.now().year,
    ),
  ),
  GoRoute(path: '/bi-weekly', builder: (_, _) => const BiWeeklyScreen()),
  GoRoute(path: '/dollars', builder: (_, _) => const DollarsScreen()),
  GoRoute(path: '/game', builder: (_, _) => const GameScreen()),
  GoRoute(path: '/manga', builder: (_, _) => const MangaScreen()),
  GoRoute(path: '/hentai', builder: (_, _) => const HentaiScreen()),
  GoRoute(path: '/nsfw', builder: (_, _) => const NsfwScreen()),
  GoRoute(path: '/users', builder: (_, _) => const DiscoveryUsersScreen()),
  GoRoute(path: '/adv', builder: (_, _) => const AdvScreen()),
  GoRoute(path: '/browser', builder: (_, _) => const BrowserScreen()),
  GoRoute(path: '/character', builder: (_, _) => const CharacterScreen()),
  GoRoute(path: '/anitama', builder: (_, _) => const AnitamaScreen()),
  GoRoute(path: '/wordcloud', builder: (_, _) => const WordCloudScreen()),
];
