import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/core/config/app_config.dart';

void main() {
  test('parses disabled database and configurable API endpoint', () {
    final config = AppConfig.fromJson({
      'environment': 'development',
      'api': {
        'enabled': false,
        'baseUrl': 'https://api.example.test',
        'timeoutSeconds': 30,
      },
      'database': {
        'enabled': false,
        'driver': 'sqlite',
        'name': 'shift_pos.sqlite',
      },
      'network': {
        'defaultMasterPort': 47831,
      },
    });

    expect(config.api.enabled, isFalse);
    expect(config.api.baseUrl, 'https://api.example.test');
    expect(config.api.timeoutSeconds, 30);
    expect(config.database.enabled, isFalse);
    expect(config.database.driver, 'sqlite');
    expect(config.network.defaultMasterPort, 47831);
  });
}
