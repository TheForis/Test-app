import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/format.dart';
import '../../state/storage_breakdown.dart';
import '../widgets/brand_logo.dart';

/// A cut-away of an underground burrow: a tunnel runs down from the Burrow
/// doorway on the surface, and every kind of data gets its own chamber. A
/// chamber's size shows how much space it takes; they fill up in turn when
/// the map appears. Free space is the empty chamber at the bottom.
class BurrowMap extends StatefulWidget {
  const BurrowMap({super.key, required this.breakdown, this.onTap});

  final StorageBreakdown breakdown;
  final ValueChanged<BreakdownPart>? onTap;

  static const _surface = 92.0;
  static const _rowHeight = 108.0;

  @override
  State<BurrowMap> createState() => _BurrowMapState();
}

class _BurrowMapState extends State<BurrowMap> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;
    final free = b.free;
    return LayoutBuilder(
      builder: (context, c) {
        final chambers = _layout(b, c.maxWidth);
        final height = BurrowMap._surface + 36 + chambers.length * BurrowMap._rowHeight;
        return SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BurrowPainter(chambers: chambers, width: c.maxWidth, progress: _controller.value),
                  ),
                ),
                // The Burrow doorway on the surface, where the tunnel begins.
                Positioned(
                  left: c.maxWidth / 2 - 34,
                  top: BurrowMap._surface - 58,
                  child: const CustomPaint(size: Size.square(68), painter: BurrowMarkPainter(background: false)),
                ),
                for (final ch in chambers) ...[
                  _label(context, ch, c.maxWidth, free),
                  if (ch.part != null && widget.onTap != null)
                    Positioned(
                      left: ch.center.dx - ch.rx,
                      top: ch.center.dy - ch.ry,
                      width: ch.rx * 2,
                      height: ch.ry * 2,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(customBorder: const StadiumBorder(), onTap: () => widget.onTap!(ch.part!)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, _Chamber ch, double width, int? free) {
    final text = Theme.of(context).textTheme;
    final left = ch.side < 0;
    final bytes = ch.part?.bytes ?? free ?? 0;
    final percent = widget.breakdown.shareOf(bytes) * 100;
    final label = Column(
      crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ch.part?.label ?? 'Free space',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        Text(
          formatBytes(bytes),
          style: text.titleMedium?.copyWith(
            color: ch.part == null ? Brand.glow : ch.part!.color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          [
            '${percent < 1 ? '<1' : percent.round()}%',
            if (ch.part?.count != null) '${ch.part!.count} files',
          ].join(' · '),
          style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
    return Positioned(
      // Labels sit across the tunnel from their chamber.
      left: left ? width * 0.56 : 16,
      right: left ? 16 : width * 0.56,
      top: ch.center.dy - 28,
      child: Opacity(opacity: ch.levelAt(_controller.value).clamp(0.0, 1.0), child: label),
    );
  }

  static List<_Chamber> _layout(StorageBreakdown b, double width) {
    final entries = <(BreakdownPart?, int)>[for (final p in b.parts) (p, p.bytes), if (b.free != null) (null, b.free!)];
    final largest = entries.fold<int>(1, (m, e) => max(m, e.$2));
    final maxRx = min(width * 0.2, 86.0);
    return [
      for (final (i, (part, bytes)) in entries.indexed)
        () {
          final side = i.isEven ? -1.0 : 1.0;
          // Area grows with size, so radius follows the square root.
          final rx = 30 + (maxRx - 30) * sqrt(bytes / largest);
          final ry = min(rx * 0.62, BurrowMap._rowHeight * 0.42);
          final y = BurrowMap._surface + 36 + i * BurrowMap._rowHeight + BurrowMap._rowHeight / 2;
          return _Chamber(
            part: part,
            center: Offset(width / 2 + side * width * 0.24, y),
            rx: rx,
            ry: ry,
            side: side,
            spine: Offset(width / 2 + side * width * 0.05, y),
            delay: i * 0.09,
          );
        }(),
    ];
  }
}

class _Chamber {
  const _Chamber({
    required this.part,
    required this.center,
    required this.rx,
    required this.ry,
    required this.side,
    required this.spine,
    required this.delay,
  });

  /// Null for free space.
  final BreakdownPart? part;
  final Offset center;
  final double rx;
  final double ry;
  final double side;

  /// Where this chamber's side tunnel meets the main tunnel.
  final Offset spine;
  final double delay;

  double levelAt(double t) => Curves.easeOutCubic.transform(((t - delay) / 0.45).clamp(0.0, 1.0));

  Rect get rect => Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
}

class _BurrowPainter extends CustomPainter {
  _BurrowPainter({required this.chambers, required this.width, required this.progress});

  final List<_Chamber> chambers;
  final double width;
  final double progress;

  static const _tunnel = Color(0xFF0C0A12);

  @override
  void paint(Canvas canvas, Size size) {
    const surface = BurrowMap._surface;

    // Soil, darker the deeper you dig.
    final soil = Rect.fromLTWH(0, surface, size.width, size.height - surface);
    canvas.drawRect(
      soil,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2A3E), Color(0xFF241C30), Color(0xFF15111D)],
        ).createShader(soil),
    );

    // Strata lines and pebbles.
    final strata = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var y = surface + 46.0; y < size.height; y += 58) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 40) {
        path.lineTo(x, y + sin((x + y) / 55) * 5);
      }
      canvas.drawPath(path, strata);
    }
    final rnd = Random(7);
    final pebble = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < (size.height / 9).round(); i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, surface + 10 + rnd.nextDouble() * (size.height - surface - 10)),
        1 + rnd.nextDouble() * 2.2,
        pebble,
      );
    }

    // The ground line, with a soft ember glow on the horizon.
    canvas.drawRect(Rect.fromLTWH(0, surface - 2, size.width, 4), Paint()..color = Brand.ember.withValues(alpha: 0.55));
    canvas.drawRect(
      Rect.fromLTWH(0, surface - 40, size.width, 40),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Brand.ember.withValues(alpha: 0.16), Brand.ember.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, surface - 40, size.width, 40)),
    );

    if (chambers.isEmpty) return;

    // Main tunnel from the doorway down past every chamber.
    final spine = Path()..moveTo(width / 2, surface - 6);
    var prev = Offset(width / 2, surface - 6);
    for (final ch in chambers) {
      final mid = (prev.dy + ch.spine.dy) / 2;
      spine.cubicTo(prev.dx, mid, ch.spine.dx, mid, ch.spine.dx, ch.spine.dy);
      prev = ch.spine;
    }
    _tunnelStroke(canvas, spine, 20);

    // Side tunnels and chambers.
    for (final ch in chambers) {
      final entry = Offset(ch.center.dx - ch.side * ch.rx * 0.85, ch.center.dy + ch.ry * 0.35);
      final side = Path()
        ..moveTo(ch.spine.dx, ch.spine.dy)
        ..quadraticBezierTo((ch.spine.dx + entry.dx) / 2, ch.spine.dy + ch.ry * 0.5, entry.dx, entry.dy);
      _tunnelStroke(canvas, side, 13);
      _chamber(canvas, ch);
    }
  }

  void _tunnelStroke(Canvas canvas, Path path, double w) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w + 5,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _tunnel
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w,
    );
  }

  void _chamber(Canvas canvas, _Chamber ch) {
    final rect = ch.rect;
    // Chambers are domed on top and flatter underneath.
    final shape = Path()
      ..moveTo(rect.left, rect.center.dy + rect.height * 0.12)
      ..cubicTo(
        rect.left,
        rect.top - rect.height * 0.1,
        rect.right,
        rect.top - rect.height * 0.1,
        rect.right,
        rect.center.dy + rect.height * 0.12,
      )
      ..cubicTo(
        rect.right,
        rect.bottom + rect.height * 0.02,
        rect.left,
        rect.bottom + rect.height * 0.02,
        rect.left,
        rect.center.dy + rect.height * 0.12,
      )
      ..close();

    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(shape, Paint()..color = _tunnel);

    final part = ch.part;
    if (part == null) {
      // Free space: an empty chamber lit by the doorway's glow.
      canvas.drawPath(
        shape,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Brand.glow.withValues(alpha: 0.18 * ch.levelAt(progress)),
              Brand.glow.withValues(alpha: 0),
            ],
          ).createShader(rect.inflate(8)),
      );
      _dashed(canvas, shape, Brand.glow.withValues(alpha: 0.55 * ch.levelAt(progress)));
      return;
    }

    // The stash fills the chamber from the floor up.
    final level = ch.levelAt(progress);
    if (level <= 0) return;
    final top = rect.bottom - (rect.height + 6) * level;
    canvas.save();
    canvas.clipPath(shape);
    final fill = Rect.fromLTRB(rect.left - 4, top, rect.right + 4, rect.bottom + 6);
    canvas.drawRect(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(part.color, Colors.white, 0.3)!, part.color, Color.lerp(part.color, Colors.black, 0.35)!],
          stops: const [0, 0.35, 1],
        ).createShader(fill),
    );
    // Shine on the surface of the stash.
    canvas.drawLine(
      Offset(rect.left, top + 2),
      Offset(rect.right, top + 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.restore();

    // Category icon inside the chamber.
    final icon = part.icon;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: min(26, ch.ry * 0.9),
          color: Colors.white.withValues(alpha: 0.9 * level),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, ch.center - Offset(painter.width / 2, painter.height / 2 - ch.ry * 0.12));
  }

  void _dashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurrowPainter old) => old.progress != progress || old.chambers != chambers || old.width != width;
}
