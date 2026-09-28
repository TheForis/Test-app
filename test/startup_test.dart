import 'package:file_manager/main.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/services/storage/storage_backend.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:file_manager/state/settings_controller.dart';
import 'package:file_manager/ui/shell.dart';
import 'package:file_manager/ui/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeded storage whose access can be withheld, like a fresh Android install.
class _PermissionBackend extends MemoryStorageBackend {
  _PermissionBackend({required this.granted}) : super(seedSamples: true);

  bool granted;

  @override
  Future<AccessState> checkAccess() async => granted ? AccessState.granted : AccessState.denied;

  @override
  Future<AccessState> requestAccess() async {
    granted = true; // The user turns on "All files access".
    return AccessState.granted;
  }
}

Future<FileIndex> _pump(WidgetTester tester, StorageBackend backend) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = await SettingsController.load();
  final index = FileIndex(backend);
  await tester.pumpWidget(FileManagerApp(settings: settings, index: index, shell: ShellController()));
  return index;
}

void main() {
  testWidgets('shows the splash, not a half-loaded home, until startup is done', (tester) async {
    final index = await _pump(tester, _PermissionBackend(granted: true));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Allow access'), findsNothing);

    await tester.runAsync(index.init);
    await tester.pump();
    // The very first frame of the home screen already has its data.
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Your burrow'), findsOneWidget);
    expect(find.text('My files'), findsWidgets); // storage locations
    expect(find.textContaining('6 files indexed'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('without access, asks for it, then opens a fully loaded home', (tester) async {
    final index = await _pump(tester, _PermissionBackend(granted: false));
    await tester.runAsync(index.init);
    await tester.pumpAndSettle();
    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.text('Your burrow'), findsNothing);

    await tester.tap(find.text('Allow access'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('My files'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(AccessScreen), findsNothing);
    expect(find.textContaining('6 files indexed'), findsOneWidget);
  });
}
