// Renders every store and README image from the real app, fed with a
// realistic showcase phone (tool/showcase_backend.dart):
//
//   docs/store/phone        1080×1920  framed, captioned (Google Play phone)
//   docs/store/tablet-7     1920×1080  foldable, framed (Play 7-inch tablet)
//   docs/store/tablet-10    2560×1440  tablet, framed (Play 10-inch tablet)
//   docs/store/chromebook   1920×1080  window, framed (Play Chromebook)
//   docs/store/raw          exact device resolutions, no frame
//   docs/store/feature-graphic.png   1024×500
//
//   flutter test tool/store_screens_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_manager/core/brand.dart';
import 'package:file_manager/main.dart';
import 'package:file_manager/services/storage/storage_backend.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:file_manager/state/settings_controller.dart';
import 'package:file_manager/ui/shell.dart';
import 'package:file_manager/ui/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'showcase_backend.dart';

// ---------------------------------------------------------------- setup

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  await _loadFont(Brand.fontFamily, [for (final w in weights) 'assets/fonts/PlusJakartaSans-$w.ttf']);
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
}

/// Pumps [child] at [canvas] logical size, runs [before], and writes a PNG.
Future<void> _render(
  WidgetTester tester,
  String path,
  Size canvas,
  double ratio,
  Widget child, {
  FileIndex? index,
  Future<void> Function(WidgetTester)? before,
}) async {
  // flutter_test draws hard-edged shadows for deterministic goldens; these
  // are marketing images, so render real soft shadows.
  debugDisableShadows = false;
  tester.view.physicalSize = canvas * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: child));
  if (index != null) await tester.runAsync(index.init);
  await tester.pumpAndSettle();
  await before?.call(tester);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
  debugDisableShadows = true;
}

/// A fresh app on the showcase phone.
/// The showcase phone before "All files access" is granted.
class _NoAccessBackend extends ShowcaseBackend {
  @override
  Future<AccessState> checkAccess() async => AccessState.denied;
}

Future<(Widget, FileIndex)> _app({ThemeMode mode = ThemeMode.light, int tab = 0, StorageBackend? backend}) async {
  SharedPreferences.setMockInitialValues({'themeMode': mode.index});
  final settings = await SettingsController.load();
  final index = FileIndex(backend ?? ShowcaseBackend());
  final shell = ShellController()..tab = tab;
  return (FileManagerApp(settings: settings, index: index, shell: shell), index);
}

// ---------------------------------------------------------------- scripted interactions

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await t.pumpAndSettle();
}

Future<void> _openDownloads(WidgetTester t) async {
  await _settle(t);
  await t.tap(find.widgetWithText(ListTile, 'Download').first);
  await _settle(t);
}

Future<void> _selectTwo(WidgetTester t) async {
  await _openDownloads(t);
  await t.longPress(find.text('Boarding pass SKP-VIE.pdf'));
  await t.pumpAndSettle();
  await t.tap(find.text('Holiday photos.zip'));
  await t.pumpAndSettle();
}

Future<void> _openArchive(WidgetTester t) async {
  await _openDownloads(t);
  await t.tap(find.text('Holiday photos.zip'));
  await _settle(t);
}

Future<void> _openBurrow(WidgetTester t) async {
  await t.tap(find.text('Explore your burrow'));
  await _settle(t);
}

Future<void> _search(WidgetTester t) async {
  await t.enterText(find.byType(TextField), 'trip');
  await t.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

// ---------------------------------------------------------------- devices

enum _Kind { phone, foldable, tablet, window }

class _Device {
  const _Device(this.kind, this.size, {required this.radius, required this.bezel});

  final _Kind kind;

  /// Screen size in dp.
  final Size size;
  final double radius;
  final double bezel;

  static const phone = _Device(_Kind.phone, Size(360, 780), radius: 34, bezel: 10);
  static const foldable = _Device(_Kind.foldable, Size(841, 701), radius: 26, bezel: 12);
  static const tablet = _Device(_Kind.tablet, Size(1280, 800), radius: 28, bezel: 20);
  static const window = _Device(_Kind.window, Size(1280, 760), radius: 12, bezel: 0);

  static const _statusBar = 28.0;
  static const _titleBar = 36.0;

  bool get hasStatusBar => kind != _Kind.window;

  /// Used in captions: "See what fills your phone".
  String get noun => switch (kind) {
    _Kind.phone || _Kind.foldable => 'phone',
    _Kind.tablet => 'tablet',
    _Kind.window => 'device',
  };
}

/// The app running on [device], drawn inside realistic hardware.
class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({required this.device, required this.app, required this.dark});

  final _Device device;
  final Widget app;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final ink = dark ? Colors.white : const Color(0xFF1D1A24);
    final appSize = d.kind == _Kind.window ? Size(d.size.width, d.size.height - _Device._titleBar) : d.size;
    Widget screen = MediaQuery(
      data: MediaQueryData(
        size: appSize,
        devicePixelRatio: 3,
        padding: EdgeInsets.only(top: d.hasStatusBar ? _Device._statusBar : 0, bottom: d.hasStatusBar ? 14 : 0),
        viewPadding: EdgeInsets.only(top: d.hasStatusBar ? _Device._statusBar : 0, bottom: d.hasStatusBar ? 14 : 0),
      ),
      child: SizedBox.fromSize(size: appSize, child: app),
    );

    if (d.hasStatusBar) {
      screen = Stack(
        children: [
          screen,
          // Status bar.
          Positioned(
            left: 20,
            right: 18,
            top: 0,
            height: _Device._statusBar,
            child: IgnorePointer(
              child: Row(
                children: [
                  Text(
                    '9:41',
                    style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Icon(Icons.signal_cellular_alt_rounded, size: 15, color: ink),
                  const SizedBox(width: 4),
                  Icon(Icons.wifi_rounded, size: 15, color: ink),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full_rounded, size: 15, color: ink),
                ],
              ),
            ),
          ),
          // Gesture navigation pill.
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 108,
                  height: 4,
                  decoration: BoxDecoration(color: ink.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
          if (d.kind == _Kind.foldable)
            // The fold.
            Positioned(
              top: 0,
              bottom: 0,
              left: d.size.width / 2 - 1,
              width: 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (d.kind == _Kind.window) {
      final bar = dark ? const Color(0xFF1C1829) : const Color(0xFFF3ECE8);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(d.radius),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 60, offset: Offset(0, 24))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: d.size.width,
              height: _Device._titleBar,
              color: bar,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const BrandLogo(size: 20),
                  const SizedBox(width: 10),
                  Text(
                    Brand.name,
                    style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  for (final icon in const [Icons.remove_rounded, Icons.crop_square_rounded, Icons.close_rounded])
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Icon(icon, size: 16, color: ink),
                    ),
                ],
              ),
            ),
            screen,
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(d.bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0A10),
        borderRadius: BorderRadius.circular(d.radius + d.bezel),
        border: Border.all(color: const Color(0xFF3B3552), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 70, offset: Offset(0, 30))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(d.radius), child: screen),
    );
  }
}

// ---------------------------------------------------------------- marketing canvas

class _Canvas extends StatelessWidget {
  const _Canvas({required this.size, required this.headline, required this.sub, required this.device});

  final Size size;
  final String headline;
  final String sub;
  final Widget device;

  @override
  Widget build(BuildContext context) {
    final portrait = size.height > size.width;
    final unit = size.shortestSide / 540;
    final text = Column(
      crossAxisAlignment: portrait ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!portrait) ...[
          BrandWordmark(
            logoSize: 30 * unit,
            style: TextStyle(color: Colors.white, fontSize: 22 * unit),
          ),
          SizedBox(height: 28 * unit),
        ],
        Text(
          headline,
          textAlign: portrait ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white,
            fontSize: 40 * unit,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -1.2 * unit,
          ),
        ),
        SizedBox(height: 12 * unit),
        Text(
          sub,
          textAlign: portrait ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Brand.glow.withValues(alpha: 0.95),
            fontSize: 18 * unit,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: Brand.fontFamily),
      home: Material(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Brand.inkLight, Brand.ink],
            ),
          ),
          child: Stack(
            children: [
              // Warm glow behind the device.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: portrait ? const Alignment(0, 0.35) : const Alignment(0.45, 0),
                      radius: 0.9,
                      colors: [Brand.ember.withValues(alpha: 0.38), Brand.ember.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(40 * unit),
                child: portrait
                    ? Column(
                        children: [
                          SizedBox(height: 16 * unit),
                          text,
                          SizedBox(height: 32 * unit),
                          Expanded(child: FittedBox(child: device)),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(width: size.width * 0.3, child: text),
                          SizedBox(width: 40 * unit),
                          Expanded(child: FittedBox(child: device)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1024×500 Play Store feature graphic.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: Brand.fontFamily),
    home: Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Brand.inkLight, Brand.ink],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.62, 0),
                    radius: 0.8,
                    colors: [Brand.ember.withValues(alpha: 0.32), Brand.ember.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 40,
              top: 40,
              child: CustomPaint(size: Size.square(420), painter: BurrowMarkPainter(background: false)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 440, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    Brand.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 104,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    Brand.tagline,
                    style: TextStyle(color: Brand.glow, fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Browse · Search · Preview · Unzip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- shots

typedef _Shot = ({
  String file,
  String headline,
  String sub,
  ThemeMode mode,
  int tab,
  Future<void> Function(WidgetTester)? before,
});

_Shot _shot(
  String file,
  String headline,
  String sub, {
  ThemeMode mode = ThemeMode.light,
  int tab = 0,
  Future<void> Function(WidgetTester)? before,
}) => (file: file, headline: headline, sub: sub, mode: mode, tab: tab, before: before);

final _home = _shot('home', 'See what fills\nyour {device}', 'Your whole storage in one glass tube.');
final _burrow = _shot(
  'burrow',
  'Explore\nyour burrow',
  'Every kind of file gets its own chamber.',
  before: _openBurrow,
);
final _browse = _shot(
  'browse',
  'Every folder,\none tap away',
  'Sort, filter, select and move in seconds.',
  tab: 1,
  before: _selectTwo,
);
final _find = _shot(
  'search',
  'Find any file\ninstantly',
  'Search by name, type, size and date.',
  mode: ThemeMode.dark,
  tab: 2,
  before: _search,
);
final _unzip = _shot(
  'unzip',
  'Unzip without\nextra apps',
  'Preview and extract ZIP, TAR, GZ and more.',
  tab: 1,
  before: _openArchive,
);
final _dark = _shot('dark', 'Beautiful\nin the dark', 'Light, dark and your own accent color.', mode: ThemeMode.dark);
final _private = _shot('private', 'Private\nby design', 'No internet access. No ads. No tracking.', tab: 3);

void _framed(String folder, Size canvas, _Device device, List<_Shot> shots) {
  for (final (i, s) in shots.indexed) {
    testWidgets('$folder ${s.file}', (t) async {
      final (app, index) = await _app(mode: s.mode, tab: s.tab);
      await _render(
        t,
        'docs/store/$folder/${i + 1}-${s.file}.png',
        canvas,
        2,
        _Canvas(
          size: canvas,
          headline: s.headline.replaceAll('{device}', device.noun),
          sub: s.sub,
          device: _DeviceFrame(device: device, app: app, dark: s.mode == ThemeMode.dark),
        ),
        index: index,
        before: s.before,
      );
    });
  }
}

void _raw(String name, Size size, double ratio, _Shot s) {
  testWidgets('raw $name', (t) async {
    final (app, index) = await _app(mode: s.mode, tab: s.tab);
    await _render(t, 'docs/store/raw/$name.png', size, ratio, app, index: index, before: s.before);
  });
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    // Screenshots should look like a touch device, without keyboard focus rings.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  });

  _framed('phone', const Size(540, 960), _Device.phone, [_home, _burrow, _browse, _find, _unzip, _dark, _private]);
  _framed('tablet-7', const Size(960, 540), _Device.foldable, [_home, _burrow, _browse, _find, _dark]);
  _framed('tablet-10', const Size(1280, 720), _Device.tablet, [_home, _burrow, _find, _browse, _dark]);
  _framed('chromebook', const Size(960, 540), _Device.window, [_dark, _browse, _find]);

  _raw('phone-home', const Size(360, 780), 3, _home);
  _raw('phone-home-dark', const Size(360, 780), 3, _dark);
  _raw('phone-burrow', const Size(360, 780), 3, _burrow);
  _raw('phone-settings', const Size(360, 780), 3, _private);
  testWidgets('raw phone-access', (t) async {
    final (app, index) = await _app(backend: _NoAccessBackend());
    await _render(t, 'docs/store/raw/phone-access.png', const Size(360, 780), 3, app, index: index);
  });
  _raw('foldable-home', const Size(841, 701), 2.625, _home);
  _raw('tablet-7-home', const Size(600, 960), 2, _home);
  _raw('tablet-10-home', const Size(1280, 800), 2, _home);
  _raw('desktop-home-dark', const Size(1440, 900), 2, _dark);
  _raw('web-search', const Size(1440, 900), 2, _find);

  testWidgets(
    'feature graphic',
    (t) => _render(t, 'docs/store/feature-graphic.png', const Size(1024, 500), 1, const _FeatureGraphic()),
  );
}
