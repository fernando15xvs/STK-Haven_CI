import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:core/core/config/supabase_config.dart';
import 'package:core/database/hive/hive_database.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';

import 'core/layout/web_layout.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await HiveDatabase.init();

  runApp(
    const ProviderScope(
      child: WebApp(),
    ),
  );
}

class WebApp extends ConsumerStatefulWidget {
  const WebApp({super.key});

  @override
  ConsumerState<WebApp> createState() => _WebAppState();
}

class _WebAppState extends ConsumerState<WebApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bibleInitProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'STK Haven',
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final savings = settings.performanceMode == PerformanceMode.savings;
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                settings.reduceMotion || savings || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const WebLayout(),
    );
  }
}
