import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/app/shift_pos_app.dart';
import 'package:shift_pos/core/config/app_config.dart';

void main() {
  testWidgets('renders the initial app shell', (tester) async {
    const config = AppConfig(
      environment: 'test',
      api: ApiConfig(
        enabled: false,
        baseUrl: 'http://127.0.0.1:8080',
        timeoutSeconds: 20,
      ),
      database: DatabaseConfig(
        enabled: false,
        driver: 'sqlite',
        name: 'shift_pos.sqlite',
      ),
      network: NetworkConfig(defaultMasterPort: 47831),
    );

    await tester.pumpWidget(const ShiftPosApp(config: config));

    expect(find.text('SHIFT POS'), findsOneWidget);
    expect(find.text('نقطة البيع'), findsWidgets);
    expect(find.text('قاعدة البيانات معطلة'), findsOneWidget);
  });
}
