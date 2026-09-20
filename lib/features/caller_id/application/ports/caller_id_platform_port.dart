import '../../domain/entities/caller_id_settings.dart';

/// Native Android Caller ID integration the feature owns as a port.
abstract interface class CallerIdPlatformPort {
  Future<CallerIdPermissionStatus> readPermissionStatus();

  Future<bool> requestCallScreeningRole();

  Future<void> openOverlaySettings();

  Future<void> syncSettings(CallerIdSettings settings);

  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,
  });
}

final class CallerIdPermissionStatus {
  const CallerIdPermissionStatus({
    required this.callScreeningRoleHeld,
    required this.canDrawOverlays,
    required this.callScreeningAvailable,
  });

  final bool callScreeningRoleHeld;
  final bool canDrawOverlays;
  final bool callScreeningAvailable;

  bool get isReady =>
      callScreeningAvailable &&
      callScreeningRoleHeld &&
      canDrawOverlays;
}
