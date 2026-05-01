import 'package:flutter/widgets.dart';
import 'package:noiselabyrinth_ui/state/profile_store.dart';

class AppScope extends InheritedNotifier<ProfileStore> {
  const AppScope({required ProfileStore store, required super.child, super.key})
    : super(notifier: store);

  static ProfileStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppScope is missing in the widget tree.');
    }
    return scope.notifier!;
  }
}
