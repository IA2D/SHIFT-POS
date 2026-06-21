import 'package:flutter/foundation.dart';

enum AppCommand {
  newOrder,
  checkoutCash,
  checkoutCard,
  holdOrder,
  focusSearch,
}

class AppCommandBus extends ChangeNotifier {
  AppCommand? _lastCommand;

  AppCommand? get lastCommand => _lastCommand;

  void dispatch(AppCommand command) {
    _lastCommand = command;
    notifyListeners();
  }
}
