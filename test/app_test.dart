import 'dart:async';

import 'package:file_manager/core/file_entry.dart';
import 'package:file_manager/main.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:file_manager/state/settings_controller.dart';
import 'package:file_manager/ui/burrow/burrow_map.dart';
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
    expect(find.text('Burrow'), findsOneWidget);
    expect(find.text('Your burrow'), findsOneWidget);
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

  testWidgets('tapping the storage card opens the burrow', (tester) async {
    await pumpApp(tester, const Size(400, 900));
    await tester.tap(find.text('Explore your burrow'));
    await tester.pumpAndSettle();
    expect(find.text('Chambers'), findsOneWidget);
    expect(find.byType(BurrowMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage card updates when the index loads after it is on screen', (tester) async {
    // Reopening the app: the card appears as soon as access is confirmed,
    // before the saved index and the background check have loaded.
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = await SettingsController.load();
    final fs = _GatedBackend();
    final index = FileIndex(fs);
    await tester.pumpWidget(FileManagerApp(settings: settings, index: index, shell: ShellController()));
    // The in-memory backend needs no real I/O, so fake time drives it.
    final init = index.init();
    await tester.pump();
    await tester.pump();
    expect(fs.scanStarted.isCompleted, isTrue);
    expect(find.text('Checking for changes…'), findsOneWidget);

    fs.gate.complete();
    await tester.pumpAndSettle();
    await init;
    await tester.pumpAndSettle();
    expect(find.text('Checking for changes…'), findsNothing);
    expect(find.textContaining('6 files indexed'), findsOneWidget);
    expect(find.textContaining(RegExp(r'(^|· )0 files indexed')), findsNothing);
  });

  testWidgets('burrow refresh panel updates after a refresh', (tester) async {
    await pumpApp(tester, const Size(400, 900));
    await tester.tap(find.text('Explore your burrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Refresh'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    // The panel and the snack bar both show the result.
    expect(find.textContaining('Up to date'), findsNWidgets(2));
  });
}

/// Seeded storage whose saved index is available at once but whose scan
/// waits until the test lets it finish.
class _GatedBackend extends MemoryStorageBackend {
  _GatedBackend() : super(seedSamples: true);

  final gate = Completer<void>();
  final scanStarted = Completer<void>();

  @override
  Future<(List<FileEntry>, DateTime)?> cachedIndex({bool showHidden = false}) async =>
      (await super.scanAll(showHidden: showHidden), DateTime.now());

  @override
  Future<List<FileEntry>> scanAll({bool showHidden = false, bool full = false}) async {
    if (!scanStarted.isCompleted) scanStarted.complete();
    await gate.future;
    return super.scanAll(showHidden: showHidden, full: full);
  }
}
