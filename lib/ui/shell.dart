import 'package:flutter/material.dart';

import 'browser/browser_screen.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';
import 'theme.dart';
import 'widgets/brand_logo.dart';

/// Lets any screen switch tabs or open a folder in the Browse tab.
class ShellController extends ChangeNotifier {
  int _tab = 0;
  String? _pendingPath;

  /// Registered by the browser so the system back button can go up a folder.
  bool Function()? browserBack;

  int get tab => _tab;

  set tab(int value) {
    if (value == _tab) return;
    _tab = value;
    notifyListeners();
  }

  void openFolder(String path) {
    _pendingPath = path;
    _tab = 1;
    notifyListeners();
  }

  String? takePendingPath() {
    final path = _pendingPath;
    _pendingPath = null;
    return path;
  }
}

class ShellScope extends InheritedNotifier<ShellController> {
  const ShellScope({super.key, required ShellController controller, required super.child})
    : super(notifier: controller);

  static ShellController of(BuildContext context) => context.getInheritedWidgetOfExactType<ShellScope>()!.notifier!;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ShellController _controller = ShellScope.of(context);

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
    (icon: Icons.folder_outlined, selected: Icons.folder_rounded, label: 'Browse'),
    (icon: Icons.search_outlined, selected: Icons.search_rounded, label: 'Search'),
    (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.removeListener(_onTab);
    _controller.addListener(_onTab);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  void _handleBack() {
    if (_controller.tab == 1 && (_controller.browserBack?.call() ?? false)) return;
    _controller.tab = 0;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Breakpoints.compact;
    final extendedRail = width >= Breakpoints.expanded + 200;

    final body = IndexedStack(
      index: _controller.tab,
      children: const [HomeScreen(), BrowserScreen(), SearchScreen(), SettingsScreen()],
    );

    return PopScope(
      canPop: _controller.tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: useRail
            ? Row(
                children: [
                  NavigationRail(
                    extended: extendedRail,
                    minExtendedWidth: 220,
                    selectedIndex: _controller.tab,
                    onDestinationSelected: (i) => _controller.tab = i,
                    labelType: extendedRail ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: extendedRail ? const BrandWordmark(logoSize: 44) : const BrandLogo(),
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: useRail
            ? null
            : NavigationBar(
                selectedIndex: _controller.tab,
                onDestinationSelected: (i) => _controller.tab = i,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
                ],
              ),
      ),
    );
  }
}
