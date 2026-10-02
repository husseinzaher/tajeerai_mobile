import '../../../../features/caller_id/domain/entities/caller_id_settings.dart';
import '../../../../features/caller_id/domain/repositories/caller_id_settings_repository.dart';
import '../local/caller_id_settings_store.dart';

class CallerIdSettingsRepositoryImpl implements CallerIdSettingsRepository {
  CallerIdSettingsRepositoryImpl(this._store);

  final CallerIdSettingsStore _store;

  @override
  Future<CallerIdSettings> read() => _store.read();

  @override
  Future<void> write(CallerIdSettings settings) => _store.write(settings);
}
