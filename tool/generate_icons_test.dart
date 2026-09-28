// Renders every launcher icon, splash image and favicon from BurrowMarkPainter.
//
//   flutter test tool/generate_icons_test.dart
//   python tool/flatten_ios_icons.py   # App Store icons must not have alpha
//
// Not part of the normal test run (it lives outside test/).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_manager/ui/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String path, int px, BurrowMarkPainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size.square(px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate icons', () async {
    const full = BurrowMarkPainter(glyphScale: 1.1);
    // Adaptive icon content must fit the 66/108 safe zone.
    const adaptive = BurrowMarkPainter(background: false, glyphScale: 0.78);
    const mono = BurrowMarkPainter(background: false, glyphScale: 0.78, monochrome: Colors.white);
    const maskable = BurrowMarkPainter(glyphScale: 0.9);

    const android = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    const res = 'android/app/src/main/res';
    for (final MapEntry(key: dpi, value: scale) in android.entries) {
      await _render('$res/mipmap-$dpi/ic_launcher.png', (48 * scale).round(), full);
      await _render('$res/mipmap-$dpi/ic_launcher_foreground.png', (108 * scale).round(), adaptive);
      await _render('$res/mipmap-$dpi/ic_launcher_monochrome.png', (108 * scale).round(), mono);
      // Pre-Android 12 splash: a 96dp mark centered on ink.
      await _render(
        '$res/drawable-$dpi/splash_logo.png',
        (96 * scale).round(),
        const BurrowMarkPainter(cornerRadius: 0.28, glyphScale: 1.12),
      );
    }

    const ios = 'ios/Runner/Assets.xcassets';
    for (final (pt, scales) in const [
      (20.0, [1, 2, 3]),
      (29.0, [1, 2, 3]),
      (40.0, [1, 2, 3]),
      (60.0, [2, 3]),
      (76.0, [1, 2]),
      (83.5, [2]),
      (1024.0, [1]),
    ]) {
      for (final s in scales) {
        final name = pt == pt.roundToDouble() ? pt.toInt().toString() : pt.toString();
        await _render('$ios/AppIcon.appiconset/Icon-App-${name}x$name@${s}x.png', (pt * s).round(), full);
      }
    }
    for (final (suffix, s) in const [('', 1), ('@2x', 2), ('@3x', 3)]) {
      await _render(
        '$ios/LaunchImage.imageset/LaunchImage$suffix.png',
        96 * s,
        const BurrowMarkPainter(cornerRadius: 0.28, glyphScale: 1.12),
      );
    }

    await _render('web/favicon.png', 64, const BurrowMarkPainter(cornerRadius: 0.28, glyphScale: 1.12));
    await _render('web/icons/Icon-192.png', 192, const BurrowMarkPainter(cornerRadius: 0.22, glyphScale: 1.1));
    await _render('web/icons/Icon-512.png', 512, const BurrowMarkPainter(cornerRadius: 0.22, glyphScale: 1.1));
    await _render('web/icons/Icon-maskable-192.png', 192, maskable);
    await _render('web/icons/Icon-maskable-512.png', 512, maskable);
    await _render('docs/brand/burrow-icon.png', 1024, const BurrowMarkPainter(cornerRadius: 0.22, glyphScale: 1.1));
  });
}
