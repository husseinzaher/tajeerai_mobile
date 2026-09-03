import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/dependencies.dart';
import 'app/config/app_config.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/device/platform_info.dart';
import 'infrastructure/logging/crash_reporter.dart';
import 'infrastructure/logging/logger.dart';
import 'infrastructure/storage/preferences_storage.dart';

/// The entry point.
///
/// Does the three things that genuinely have to happen before any widget
/// builds -- resolve configuration, open the database, read preferences --
/// and hands each to the provider that declares it. Everything else is
/// constructed lazily by Riverpod when first read.
///
/// The async initialisation lives here rather than behind a `FutureProvider`
/// so that no screen ever has to render a loading state for "the database is
/// still opening".
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.resolve();

  final reporter = LoggingCrashReporter(
    Logger('app', verbose: config.environment.verboseDiagnostics),
  );

  installCrashHandlers(reporter);

  await runGuardedWith(reporter, () async {
    final database = AppDatabase();
    final preferences = await PreferencesStorage.open();
    final platform = await PlatformInfo.resolve();

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          appDatabaseProvider.overrideWithValue(database),
          preferencesStorageProvider.overrideWithValue(preferences),
          platformInfoProvider.overrideWithValue(platform),
          crashReporterProvider.overrideWithValue(reporter),
        ],
        child: const TajeerApp(),
      ),
    );
  });
}
