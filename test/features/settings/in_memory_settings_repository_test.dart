import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/settings/data/in_memory_settings_repository.dart';
import 'package:shift_pos/features/settings/domain/pos_settings.dart';

void main() {
  test('returns configured POS settings', () async {
    final repository = InMemorySettingsRepository(
      settings: const PosSettings(
        restaurantNameAr: 'مطعم الاختبار',
        currencySymbol: 'EGP',
        taxRate: 12,
        serviceRate: 5,
        deliveryFee: 30,
      ),
    );

    final settings = await repository.getPosSettings();

    expect(settings.restaurantNameAr, 'مطعم الاختبار');
    expect(settings.currencySymbol, 'EGP');
    expect(settings.taxRate, 12);
    expect(settings.serviceRate, 5);
    expect(settings.deliveryFee, 30);
  });
}
