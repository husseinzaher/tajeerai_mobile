import '../../../../infrastructure/device/caller_id/android_caller_id_gateway.dart';
import '../../application/ports/caller_id_platform_port.dart';
import '../../domain/entities/caller_id_settings.dart';

/// Adapts the infrastructure gateway to the feature port.
class CallerIdPlatformAdapter implements CallerIdPlatformPort {
  CallerIdPlatformAdapter({AndroidCallerIdGateway? gateway})
    : _gateway = gateway ?? const AndroidCallerIdGateway();

  final AndroidCallerIdGateway _gateway;

  @override
  Future<CallerIdPermissionStatus> readPermissionStatus() async {
    final Map<String, Object?> status = await _gateway.readPermissionStatus();

    return CallerIdPermissionStatus(
      callScreeningRoleHeld: status['callScreeningRoleHeld'] == true,
      canDrawOverlays: status['canDrawOverlays'] == true,
      callScreeningAvailable: status['callScreeningAvailable'] != false,
    );
  }

  @override
  Future<bool> requestCallScreeningRole() {
    return _gateway.requestCallScreeningRole();
  }

  @override
  Future<void> openOverlaySettings() {
    return _gateway.openOverlaySettings();
  }

  @override
  Future<void> syncSettings(CallerIdSettings settings) {
    return _gateway.syncSettings(settings.toNativeMap());
  }

  @override
  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,
  }) {
    return _gateway.syncRuntimeConfig(
      databasePath: databasePath,
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
    );
  }
}

/// No-op adapter for tests and unsupported platforms.
class NoopCallerIdPlatformAdapter implements CallerIdPlatformPort {
  const NoopCallerIdPlatformAdapter();

  @override
  Future<CallerIdPermissionStatus> readPermissionStatus() async {
    return const CallerIdPermissionStatus(
      callScreeningRoleHeld: false,
      canDrawOverlays: false,
      callScreeningAvailable: false,
    );
  }

  @override
  Future<bool> requestCallScreeningRole() async => false;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> syncSettings(CallerIdSettings settings) async {}

  @override
  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,
  }) async {}
}
