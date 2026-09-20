import '../ports/caller_id_platform_port.dart';
import '../../domain/entities/caller_id_settings.dart';
import '../../domain/repositories/caller_id_settings_repository.dart';

/// Reads, writes, and syncs Caller ID settings.
class CallerIdSettingsCoordinator {
  CallerIdSettingsCoordinator({
    required CallerIdSettingsRepository settings,
    required CallerIdPlatformPort platform,
  }) : _settings = settings,
       _platform = platform;

  final CallerIdSettingsRepository _settings;
  final CallerIdPlatformPort _platform;

  Future<CallerIdSettings> read() => _settings.read();

  Future<CallerIdSettings> save(CallerIdSettings settings) async {
    await _settings.write(settings);
    await _platform.syncSettings(settings);

    return settings;
  }

  Future<CallerIdPermissionStatus> permissionStatus() {
    return _platform.readPermissionStatus();
  }

  Future<bool> requestCallScreeningRole() {
    return _platform.requestCallScreeningRole();
  }

  Future<void> openOverlaySettings() {
    return _platform.openOverlaySettings();
  }

  Future<void> syncRuntimeConfig({
    required String databasePath,
    required String apiBaseUrl,
    String? accessToken,
  }) {
    return _platform.syncRuntimeConfig(
      databasePath: databasePath,
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
    );
  }
}
