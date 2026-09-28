import 'package:flutter/material.dart';

import '../../core/brand.dart';

/// Paints the Burrow mark: a folder with an arched doorway at its base and a
/// warm glow inside. This painter is also used by `tool/generate_icons_test.dart`
/// to render every launcher icon, so the app and its icons never drift apart.
class BurrowMarkPainter extends CustomPainter {
  const BurrowMarkPainter({this.background = true, this.glyphScale = 1, this.monochrome, this.cornerRadius = 0});

  /// Fill the canvas with the ink gradient behind the glyph.
  final bool background;

  /// Shrinks the glyph around the center (adaptive icons need a safe zone).
  final double glyphScale;

  /// When set, draws the glyph in this single color with the doorway cut out.
  final Color? monochrome;

  /// Rounds the background, as a fraction of the shortest side.
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & size;

    if (background) {
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.inkLight, Brand.ink],
        ).createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius * s)), bg);
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(glyphScale * s);
    canvas.translate(-0.5, -0.5);

    // Everything below is in a 1×1 box.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 1, 1), Paint());

    final folder = Paint();
    if (monochrome != null) {
      folder.color = monochrome!;
    } else {
      folder.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Brand.emberLight, Brand.ember],
      ).createShader(const Rect.fromLTRB(0.18, 0.24, 0.82, 0.78));
    }

    // Folder tab and body.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        0.18,
        0.25,
        0.50,
        0.42,
        topLeft: const Radius.circular(0.055),
        topRight: const Radius.circular(0.055),
      ),
      folder,
    );
    canvas.drawRRect(RRect.fromLTRBR(0.18, 0.33, 0.82, 0.77, const Radius.circular(0.075)), folder);

    // Lighter lip across the top of the body gives the folder some depth.
    if (monochrome == null) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          0.18,
          0.33,
          0.82,
          0.405,
          topLeft: const Radius.circular(0.075),
          topRight: const Radius.circular(0.075),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.16),
      );
    }

    // The arched doorway, sitting on the folder's bottom edge.
    final door = Path()
      ..moveTo(0.40, 0.77)
      ..lineTo(0.40, 0.60)
      ..arcToPoint(const Offset(0.60, 0.60), radius: const Radius.circular(0.10))
      ..lineTo(0.60, 0.77)
      ..close();
    canvas.drawPath(
      door,
      monochrome != null || !background ? (Paint()..blendMode = BlendMode.clear) : (Paint()..color = Brand.ink),
    );

    // Glow inside the doorway.
    if (monochrome == null) {
      canvas.drawCircle(
        const Offset(0.5, 0.685),
        0.05,
        Paint()
          ..shader = RadialGradient(colors: [Brand.glow, Brand.glow.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: const Offset(0.5, 0.685), radius: 0.05)),
      );
      canvas.drawCircle(const Offset(0.5, 0.685), 0.022, Paint()..color = Brand.glow);
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(BurrowMarkPainter old) =>
      old.background != background ||
      old.glyphScale != glyphScale ||
      old.monochrome != monochrome ||
      old.cornerRadius != cornerRadius;
}

/// The app icon as a rounded tile.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${Brand.name} logo',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: const BurrowMarkPainter(cornerRadius: 0.28, glyphScale: 1.12)),
  );
}

/// Logo plus the product name.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.logoSize = 40, this.style});
  final double logoSize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandLogo(size: logoSize),
      SizedBox(width: logoSize * 0.3),
      Text(
        Brand.name,
        style: (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
}
