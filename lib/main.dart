import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/auth/site_cookies.dart';
import 'core/storage/cache.dart';
import 'core/storage/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.init();
  await SiteCookiesStore.instance.init();
  await Cache.instance.init();
  runApp(const ProviderScope(child: BangumiApp()));
}
