import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

class AppStateScope extends InheritedWidget {
  const AppStateScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing from the widget tree.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) {
    return dependencies != oldWidget.dependencies;
  }
}
