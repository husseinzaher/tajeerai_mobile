import '../../domain/entities/caller_id_settings.dart';

/// Native Android Caller ID integration the feature owns as a port.
abstract interface class CallerIdPlatformPort {
  Future<CallerIdPermissionStatus> readPermissionStatus();

  Future<bool> requestCallScreeningRole();

  /// Asks for read access to the phone's contacts, and resolves with whether
  /// it was granted. Telecom consults a screening app for a caller already
  /// in the phone's contacts only when the app holds this permission.
  Future<bool> requestContactsPermission();

  /// Asks to read the phone's call state, and resolves with whether it was
  /// granted. It is what lets the card stay for the whole call and show a
  /// summary when the call ends.
  Future<bool> requestPhoneStatePermission();

  Future<void> openOverlaySettings();

  Future<void> syncSettings(CallerIdSettings settings);

  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,

    /// The app's language code, so the native card reads like the app does.
    String? locale,
  });
}

final class CallerIdPermissionStatus {
  const CallerIdPermissionStatus({
    required this.callScreeningRoleHeld,
    required this.canDrawOverlays,
    required this.callScreeningAvailable,
    this.readContactsGranted = false,
    this.readPhoneStateGranted = false,
  });

  final bool callScreeningRoleHeld;
  final bool canDrawOverlays;
  final bool callScreeningAvailable;

  /// Without it the card appears only for callers the phone does not know.
  final bool readContactsGranted;

  /// Without it the card cannot tell when the call ends, so it falls back to
  /// a timer and shows no summary.
  final bool readPhoneStateGranted;

  bool get isReady =>
      callScreeningAvailable &&
      callScreeningRoleHeld &&
      canDrawOverlays &&
      readContactsGranted &&
      readPhoneStateGranted;

  /// How many of the grants are still missing, for the setup copy.
  int get missingCount =>
      (callScreeningRoleHeld ? 0 : 1) +
      (canDrawOverlays ? 0 : 1) +
      (readContactsGranted ? 0 : 1) +
      (readPhoneStateGranted ? 0 : 1);
}
