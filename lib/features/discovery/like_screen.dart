import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/recommend_list.dart';

/// 猜你喜欢
///
/// 原项目以用户收藏为数据源做客户端推荐评分, 本页移植该逻辑:
/// v0 收藏 API → 客户端评分 → 降序列表。右上角设置对齐原版 ActionSheet。
class LikeScreen extends ConsumerStatefulWidget {
  final String userId;

  const LikeScreen({super.key, this.userId = ''});

  @override
  ConsumerState<LikeScreen> createState() => _LikeScreenState();
}

class _LikeScreenState extends ConsumerState<LikeScreen> {
  int _type = 2;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final title = widget.userId.isEmpty ? '猜你喜欢' : '${widget.userId}的猜你喜欢';
    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => showBgmSheet<void>(
              context: context,
              builder: (ctx) => _LikeSettingSheet(userId: widget.userId),
            ),
          ),
        ],
      ),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('此功能依赖收藏数据, 请先登录'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '去登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: BgmSegmented<int>(
                    expand: true,
                    values: kRecommendTypes,
                    selected: _type,
                    onSelect: (v) => setState(() => _type = v),
                  ),
                ),
                Expanded(child: RecommendList(subjectType: _type)),
              ],
            ),
    );
  }
}

class _LikeSettingSheet extends ConsumerStatefulWidget {
  final String userId;

  const _LikeSettingSheet({required this.userId});

  @override
  ConsumerState<_LikeSettingSheet> createState() => _LikeSettingSheetState();
}

class _LikeSettingSheetState extends ConsumerState<_LikeSettingSheet> {
  late final _user = TextEditingController(text: widget.userId);

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  void _openUser() {
    final id = _user.text.trim();
    if (id.isEmpty) {
      showBgmToast(context, '用户 ID 不能为空');
      return;
    }
    Navigator.pop(context);
    context.push('/like?userId=${Uri.encodeQueryComponent(id)}');
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final store = ref.watch(settingsStoreProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('设置', style: ds.section)),
                  BgmHeaderAction(
                    tooltip: '说明',
                    icon: const Icon(Icons.info_outline, size: 18),
                    onPressed: () => context.push('/tips'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '这是基于全站条目中「猜你喜欢」和客户端「分类排行」，并根据您的收藏，计算的一个列表。此功能非 AI 大模型推导结果，只是在本地进行的一些很简单规则累加计算。所以只要你收藏、打分越多，数据就会越多。',
                style: ds.caption,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _user,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _openUser(),
                      decoration: InputDecoration(
                        hintText: '可输入用户 ID 查看其他人的结果',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: ds.border),
                        ),
                      ),
                    ),
                  ),
                  BgmHeaderAction(
                    tooltip: '查看',
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: _openUser,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('显示已收藏条目', style: ds.bodyStrong),
                        const SizedBox(height: 4),
                        Text(
                          '是否显示该计算用户已收藏的条目，若为浏览自己的数据，建议关闭；若为浏览基于他人的数据，建议打开',
                          style: ds.tiny,
                        ),
                      ],
                    ),
                  ),
                  BgmSwitch(
                    value: store.likeCollected,
                    onChanged: store.setLikeCollected,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('推荐值计算维度', style: ds.bodyStrong),
              const SizedBox(height: 4),
              Text('计算非基于结果中显示的条目项，而是推荐这个项的条目', style: ds.tiny),
              const SizedBox(height: 8),
              for (var i = 0; i < kLikeRecReasons.length; i++) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kLikeRecReasons[i].$1, style: ds.bodyStrong),
                          const SizedBox(height: 2),
                          Text(kLikeRecReasons[i].$2, style: ds.tiny),
                        ],
                      ),
                    ),
                    BgmSwitch(
                      value: store.likeRec[i] == 1,
                      onChanged: (v) => store.setLikeRecAt(i, v),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
