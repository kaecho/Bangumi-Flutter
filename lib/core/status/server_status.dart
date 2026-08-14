import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_endpoints.dart';
import '../storage/settings_store.dart';

/// 主站服务可用性 (原项目 systemStore.serverStatus)
class ServerStatus {
  final String status;
  final String message;

  const ServerStatus({this.status = '', this.message = ''});

  bool get isOk => status == 'ok';
  bool get isDegraded => status == 'degraded';
  bool get isDown => status == 'down';
}

final serverStatusProvider = FutureProvider<ServerStatus>((ref) async {
  final notify = ref.watch(settingsStoreProvider).serverStatusNotify;
  if (notify == 'none') return const ServerStatus(status: 'ok');
  try {
    final resp = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ),
    ).get<dynamic>(apiMkStatusMini());
    final data = resp.data;
    if (data is Map) {
      return ServerStatus(
        status: data['status']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
      );
    }
  } catch (_) {}
  return const ServerStatus(status: 'down', message: 'probe failed');
});

/// 原项目 notifyServerStatus: none 不显示; degraded 含中断; down 仅中断
bool shouldNotifyServerStatus(String setting, String status) {
  if (setting == 'none') return false;
  if (setting == 'degraded') return status == 'degraded' || status == 'down';
  if (setting == 'down') return status == 'down';
  return false;
}
