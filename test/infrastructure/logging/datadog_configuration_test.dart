import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/logging/datadog_configuration.dart';

void main() {
  test('points RUM at the US1 mobile application', () {
    final configuration = buildDatadogConfiguration('production');

    expect(configuration.clientToken, datadogClientToken);
    expect(configuration.env, 'production');
    expect(configuration.site, DatadogSite.us1);
    expect(configuration.service, datadogServiceName);
    expect(configuration.nativeCrashReportEnabled, isTrue);
    expect(configuration.loggingConfiguration, isNotNull);
    expect(configuration.rumConfiguration?.applicationId, datadogApplicationId);
  });

  test('uses the deployment name it is given', () {
    expect(buildDatadogConfiguration('staging').env, 'staging');
    expect(buildDatadogConfiguration('development').env, 'development');
  });
}
