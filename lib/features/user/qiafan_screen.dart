import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import 'user_models.dart';
import 'zone_screen.dart';

/// 我的卡片 (Bangumi 签名卡片预览)
class QiafanScreen extends ConsumerWidget {
  const QiafanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的卡片')),
      body: me == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('未登录'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('登录'),
                  ),
                ],
              ),
            )
          : _QiafanCard(me: me),
    );
  }
}

class _QiafanCard extends ConsumerWidget {
  final User me;

  const _QiafanCard({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(zoneStatsProvider(userPathId(me)));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
                // 卡片预览
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Avatar(url: me.avatarUrl, size: 48, name: me.displayName),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        me.displayName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        userGroupText[me.userGroup] ?? '会员',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  tooltip: '用户空间',
                                  onPressed: () => context.push('/user/${userPathId(me)}'),
                                ),
                              ],
                            ),
                            if (me.sign.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                me.sign,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            stats.when(
                              loading: () => const SizedBox(height: 30),
                              error: (_, _) => const SizedBox(height: 30),
                              data: (s) => Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  for (final (type, label) in kUserTypeTabs)
                                    Text(
                                      '$label ${s.total(type)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '卡片为 Bangumi 网页端签名档的本地预览。\n完整签名档可在网页端「设置 - 签名档」中生成。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
    );
  }
}
