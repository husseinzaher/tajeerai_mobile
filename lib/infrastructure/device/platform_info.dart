import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Facts about the running build and device.
///
/// Used for the API's `User-Agent` and for diagnostics. Carries no device
/// identifier: nothing in the app needs to tell two installations apart, and
/// collecting one anyway is how an app acquires a tracking surface it never
/// intended.
class PlatformInfo {
  const PlatformInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.operatingSystem,
  });

  static Future<PlatformInfo> resolve() async {
    final info = await PackageInfo.fromPlatform();

    return PlatformInfo(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      operatingSystem: Platform.operatingSystem,
    );
  }

  final String appVersion;
  final String buildNumber;
  final String operatingSystem;

  /// Identifies the client to the backend, matching how the web client is
  /// recognised in the auth controller's `user-agent` handling.
  String get userAgent =>
      'TajeerAI-Mobile/$appVersion+$buildNumber ($operatingSystem)';
}
