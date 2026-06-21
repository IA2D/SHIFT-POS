import '../domain/pos_settings.dart';
import '../domain/settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({
    PosSettings settings = const PosSettings(
      restaurantNameAr: 'SHIFT POS',
      currencySymbol: 'ج.م',
      taxRate: 14,
      serviceRate: 0,
      deliveryFee: 25,
    ),
  }) : _settings = settings;

  PosSettings _settings;

  @override
  Future<PosSettings> getPosSettings() async {
    return _settings;
  }

  @override
  Future<PosSettings> savePosSettings(PosSettings settings) async {
    _settings = settings;
    return settings;
  }
}
