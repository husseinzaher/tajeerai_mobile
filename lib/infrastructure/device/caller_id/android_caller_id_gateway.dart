import 'package:flutter/services.dart';

/// Android MethodChannel bridge for Caller ID.
///
/// Accepts plain maps so infrastructure never imports a feature module.
class AndroidCallerIdGateway {
  const AndroidCallerIdGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.tajeerai.mobile/caller_id',
  );

  Future<Map<String, Object?>> readPermissionStatus() async {
    final Object? result = await _channel.invokeMethod<Object?>(
      'getPermissionStatus',
    );

    if (result is Map<Object?, Object?>) {
      return result.map(
        (Object? key, Object? value) =>
            MapEntry(key.toString(), value),
      );
    }

    return const <String, Object?>{
      'callScreeningRoleHeld': false,
      'canDrawOverlays': false,
      'callScreeningAvailable': false,
    };
  }

  Future<bool> requestCallScreeningRole() async {
    final Object? result = await _channel.invokeMethod<Object?>(
      'requestCallScreeningRole',
    );

    return result == true;
  }

  Future<void> openOverlaySettings() {
    return _channel.invokeMethod<void>('openOverlaySettings');
  }

  Future<void> syncSettings(Map<String, Object> settings) {
    return _channel.invokeMethod<void>('syncSettings', settings);
  }

  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,
  }) {
    return _channel.invokeMethod<void>('syncRuntimeConfig', <String, Object?>{
      'databasePath': databasePath,
      'apiBaseUrl': apiBaseUrl,
      'accessToken': accessToken,
    });
  }
}
