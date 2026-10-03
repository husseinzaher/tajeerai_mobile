import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/dependencies.dart';
import 'app/config/app_config.dart';
import 'infrastructure/storage/database/app_database.dart';
import 'infrastructure/device/platform_info.dart';
import 'infrastructure/logging/crash_reporter.dart';
import 'infrastructure/logging/datadog_configuration.dart';
import 'infrastructure/logging/datadog_crash_reporter.dart';
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
  final config = AppConfig.resolve();

  // `runApp` initializes the binding, installs Datadog's error handlers, then
  // runs this callback. The callback is synchronous on purpose: the SDK does
  // not await it, so the database open is scheduled and still finishes before
  // the first widget, which is what the awaits below are for.
  await DatadogSdk.runApp(
    buildDatadogConfiguration(config.environment.name),
    TrackingConsent.granted,
    () {
      final logs = LoggingCrashReporter(
        Logger('app', verbose: config.environment.verboseDiagnostics),
      );
      final reporter = DatadogCrashReporter(logs);

      // After Datadog's handlers, so framework and platform errors still
      // reach RUM. The logging reporter is the one chained here: the
      // forwarding reporter also writes to RUM, and using it on this path
      // would record the same framework error twice.
      installCrashHandlers(logs);

      unawaited(
        runGuardedWith(reporter, () async {
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
        }),
      );
    },
  );
}
