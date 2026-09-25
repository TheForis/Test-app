import 'package:flutter/material.dart';

import 'core/format.dart';
import 'services/storage/storage_backend.dart';
import 'state/app_scope.dart';
import 'state/file_index.dart';
import 'state/settings_controller.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDateFormatting(WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag());
  final settings = await SettingsController.load();
  final index = FileIndex(StorageBackend.create());
  runApp(FileManagerApp(settings: settings, index: index, shell: ShellController()));
  index.init(showHidden: settings.showHidden);
}

class FileManagerApp extends StatelessWidget {
  const FileManagerApp({super.key, required this.settings, required this.index, required this.shell});

  final SettingsController settings;
  final FileIndex index;
  final ShellController shell;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      index: index,
      child: ShellScope(
        controller: shell,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final seed = Color(settings.seedColor);
            return MaterialApp(
              title: 'File Manager',
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: buildTheme(Brightness.light, seed),
              darkTheme: buildTheme(Brightness.dark, seed),
              home: const AppShell(),
            );
          },
        ),
      ),
    );
  }
}
