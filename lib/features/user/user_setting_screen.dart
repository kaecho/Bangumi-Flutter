import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';

import '../../shared/widgets/cover.dart';

/// 个人设置 (昵称/签名展示 + 同步设置)
class UserSettingScreen extends ConsumerWidget {
  const UserSettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人设置'),
        actions: [
          IconButton(
            tooltip: '网页端设置',
            icon: const Icon(Icons.check),
            onPressed: () =>
                context.push('/web/${Uri.encodeComponent('$kHost/settings')}'),
          ),
        ],
      ),

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
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Avatar(
                          url: me.avatarUrl,
                          size: 56,
                          name: me.displayName,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                me.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '@${me.username.isEmpty ? me.id : me.username}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (me.sign.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  me.sign,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: '用户空间',
                          onPressed: () {
                            final id = me.username.isEmpty
                                ? '${me.id}'
                                : me.username;
                            context.push('/user/$id');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('Bilibili 同步'),
                        subtitle: const Text('将收藏进度同步到 Bilibili'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.push('/sync/bilibili'),
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('豆瓣同步'),
                        subtitle: const Text('将收藏进度同步到豆瓣'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.push('/sync/douban'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('网页端设置'),
                    subtitle: const Text('在浏览器中修改昵称/签名/头像'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push(
                      '/web/${Uri.encodeComponent('https://bgm.tv/settings')}',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
