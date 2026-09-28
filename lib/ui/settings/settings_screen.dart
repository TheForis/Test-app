import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/app_scope.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/scan_feedback.dart';
import '../../core/brand.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Ember (the Burrow default) first, then alternatives.
  static const _colors = [0xFFF2542D, 0xFF6750A4, 0xFF0061A4, 0xFF006E1C, 0xFFB3261E, 0xFF006A6A];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, scope.index]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ContentWidth(
          maxWidth: 720,
          child: ListView(
            padding: pagePadding(context).copyWith(bottom: 32),
            children: [
              _section(context, 'Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          // Icons plus check marks squeeze "System" onto two lines on small phones.
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: narrow ? null : const Icon(Icons.brightness_auto_rounded),
                              label: const Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: narrow ? null : const Icon(Icons.light_mode_rounded),
                              label: const Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: narrow ? null : const Icon(Icons.dark_mode_rounded),
                              label: const Text('Dark'),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (s) => settings.themeMode = s.first,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Accent color'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final c in _colors)
                            Semantics(
                              button: true,
                              selected: settings.seedColor == c,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => settings.seedColor = c,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(c),
                                  child: settings.seedColor == c
                                      ? const Icon(Icons.check_rounded, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _section(context, 'Files'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.visibility_rounded),
                      title: const Text('Show hidden files'),
                      subtitle: const Text('Files and folders starting with "."'),
                      value: settings.showHidden,
                      onChanged: (v) {
                        settings.showHidden = v;
                        scope.index.refresh(showHidden: v);
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.grid_view_rounded),
                      title: const Text('Grid view'),
                      subtitle: const Text('Show folders as a grid of cards'),
                      value: settings.gridView,
                      onChanged: (v) => settings.gridView = v,
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Rescan storage'),
                      isThreeLine: scope.index.lastReport != null,
                      subtitle: Text(
                        scope.index.lastScan == null
                            ? 'Not scanned yet'
                            : '${formatCount(scope.index.files.length)} files • ${formatBytes(scope.index.totalBytes)} • '
                                  '${formatDate(scope.index.lastScan!)}'
                                  '${scope.index.lastReport == null ? '' : '\n${describeScan(scope.index.lastReport!)}'}',
                      ),
                      trailing: scope.index.loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : null,
                      onTap: scope.index.loading ? null : () => refreshWithReport(context, full: true),
                    ),
                    if (scope.backend.isDeviceStorage)
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings_rounded),
                        title: const Text('App permissions'),
                        subtitle: const Text('Storage access and installing apps'),
                        onTap: scope.backend.openAccessSettings,
                      ),
                  ],
                ),
              ),
              _section(context, 'About'),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const BrandLogo(size: 48),
                  title: const Text(Brand.name, style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    scope.backend.isDeviceStorage ? '${Brand.tagline} Browse, search, open, unzip and install files.' : 'Web edition: your browser keeps device folders private, so files you import live in this tab.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
