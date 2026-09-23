import 'dart:async';

import 'package:core/core/config/supabase_config.dart';
import 'package:core/database/hive/hive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/stk_haven_app.dart';

typedef PlatformServicesInitializer = Future<void> Function();

/// Shared bootstrap for both native mobile targets.
///
/// The caller injects only the services for the target platform so Android and
/// iOS do not need to import one another's startup layers.
Future<void> bootstrapMobileApp({
  required PlatformServicesInitializer initializePlatformServices,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  Intl.defaultLocale = 'es';

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await HiveDatabase.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );

  // Native notification/background plugins are useful but not required for the
  // first interaction. Give the first screen a short idle window before plugin
  // registration and scheduling work begins.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      _initializePlatformServicesBestEffort(initializePlatformServices),
    );
  });
}

Future<void> _initializePlatformServicesBestEffort(
  PlatformServicesInitializer initializePlatformServices,
) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    await initializePlatformServices();
  } catch (error, stackTrace) {
    debugPrint('Platform services initialization skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
