import 'pos_settings.dart';

abstract interface class SettingsRepository {
  Future<PosSettings> getPosSettings();
}
