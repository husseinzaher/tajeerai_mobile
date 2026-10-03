import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

/// Public RUM client token for the mobile application.
///
/// This is not an API key. Datadog issues it to be embedded in the client,
/// and it can only ingest RUM for this application.
const String datadogClientToken = 'pubc4e5aec05b5c0a200e8fc2203940b064';

/// Datadog RUM application id for the mobile application.
const String datadogApplicationId = '9c0ef6af-9ab5-4f42-9fa6-770dab83374a';

/// Service name reported with every RUM event and log.
const String datadogServiceName = 'tajeerai-mobile';

/// The configuration [DatadogSdk.runApp] starts with.
///
/// [env] is the deployment name (`development`, `staging`, `production`),
/// the same value `Environment` already resolves at build time.
DatadogConfiguration buildDatadogConfiguration(String env) {
  return DatadogConfiguration(
    clientToken: datadogClientToken,
    env: env,
    site: DatadogSite.us1,
    service: datadogServiceName,
    nativeCrashReportEnabled: true,
    loggingConfiguration: DatadogLoggingConfiguration(),
    rumConfiguration: DatadogRumConfiguration(
      applicationId: datadogApplicationId,
    ),
  );
}
