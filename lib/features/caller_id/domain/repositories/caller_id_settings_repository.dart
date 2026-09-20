import '../entities/caller_id_settings.dart';

abstract interface class CallerIdSettingsRepository {
  Future<CallerIdSettings> read();

  Future<void> write(CallerIdSettings settings);
}
