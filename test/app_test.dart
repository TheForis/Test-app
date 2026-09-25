import 'package:file_manager/main.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:file_manager/state/settings_controller.dart';
import 'package:file_manager/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = await SettingsController.load();
  final index = FileIndex(MemoryStorageBackend(seedSamples: true));
  await tester.pumpWidget(FileManagerApp(settings: settings, index: index, shell: ShellController()));
  await tester.runAsync(() => index.init());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone layout: category cards and recent files', (tester) async {
    await pumpApp(tester, const Size(400, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Images'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Recent files'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Recent files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout uses a navigation rail', (tester) async {
    await pumpApp(tester, const Size(1400, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browse tab lists folders and opens one', (tester) async {
    await pumpApp(tester, const Size(400, 900));
    await tester.tap(find.text('Browse'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Downloads'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Downloads'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('sample-archive.zip'), findsOneWidget);
  });

  testWidgets('search filters the index', (tester) async {
    await pumpApp(tester, const Size(400, 900));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notes');
    await tester.pumpAndSettle();
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('1 result'), findsOneWidget);
  });
}
