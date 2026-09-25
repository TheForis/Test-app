import 'package:flutter/widgets.dart';

import '../services/storage/storage_backend.dart';
import 'file_index.dart';
import 'settings_controller.dart';

/// Makes the app-wide controllers reachable from any widget.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.settings, required this.index, required super.child});

  final SettingsController settings;
  final FileIndex index;

  StorageBackend get backend => index.backend;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  /// Notifies all listeners that files changed and re-scans storage.
  Future<void> filesChanged() => index.changed(showHidden: settings.showHidden);

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
