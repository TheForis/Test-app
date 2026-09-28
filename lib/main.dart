import 'package:flutter/material.dart';

import 'core/brand.dart';
import 'core/format.dart';
import 'services/storage/storage_backend.dart';
import 'state/app_scope.dart';
import 'state/file_index.dart';
import 'state/settings_controller.dart';
import 'ui/shell.dart';
import 'ui/startup_gate.dart';
import 'ui/theme.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the system splash up while access is checked and the home screen's
  // data loads, so the first thing drawn is the finished screen. If startup
  // is slow, the matching Flutter splash takes over after 1.5 s.
  binding.deferFirstFrame();
  var firstFrameAllowed = false;
  void allowFirstFrame() {
    if (firstFrameAllowed) return;
    firstFrameAllowed = true;
    binding.allowFirstFrame();
  }

  await initDateFormatting(binding.platformDispatcher.locale.toLanguageTag());
  final settings = await SettingsController.load();
  final index = FileIndex(StorageBackend.create());
  void onIndex() {
    if (!index.ready) return;
    index.removeListener(onIndex);
    allowFirstFrame();
  }

  index.addListener(onIndex);
  Future<void>.delayed(const Duration(milliseconds: 1500), allowFirstFrame);
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
              title: Brand.name,
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: buildTheme(Brightness.light, seed),
              darkTheme: buildTheme(Brightness.dark, seed),
              home: const StartupGate(),
            );
          },
        ),
      ),
    );
  }
}
