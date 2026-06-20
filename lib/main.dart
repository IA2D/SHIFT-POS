import 'package:flutter/material.dart';

import 'app/shift_pos_app.dart';
import 'core/config/config_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await ConfigLoader.load();

  runApp(ShiftPosApp(config: config));
}
