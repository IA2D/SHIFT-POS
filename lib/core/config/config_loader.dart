import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_config.dart';

class ConfigLoader {
  const ConfigLoader._();

  static Future<AppConfig> load({
    String assetPath = 'assets/config/app_config.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AppConfig.fromJson(json);
  }
}
