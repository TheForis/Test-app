import 'package:flutter/material.dart';

/// One colored band of liquid in a [StorageTube].
class TubeSegment {
  const TubeSegment({required this.label, required this.bytes, required this.color});

  final String label;
  final int bytes;
  final Color color;
}

/// A glass tube filled with colored liquid, one band per kind of data. The
/// empty glass on the right is free space. The fill animates in on first show.
class StorageTube extends StatelessWidget {
  const StorageTube({super.key, required this.segments, required this.capacity, this.height = 30});

  final List<TubeSegment> segments;

  /// Bytes that fill the whole tube.
  final int capacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final used = segments.fold<int>(0, (a, s) => a + s.bytes);
    final fill = capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);
    final inner = BorderRadius.circular(height / 2 - 3);

    return Semantics(
      label: 'Storage ${(fill * 100).round()}% full',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fill),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, level, _) => Container(
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: radius,
            // Frosted glass.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.05)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: inner,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: level,
                    heightFactor: 1,
                    child: ClipRRect(
                      borderRadius: inner,
                      child: Row(
                        children: [
                          for (final (i, s) in segments.indexed)
                            if (s.bytes > 0) ...[
                              if (i > 0) Container(width: 1.5, color: Colors.black.withValues(alpha: 0.25)),
                              Expanded(
                                // Keep tiny slices visible.
                                flex: (s.bytes * 1000 / used).round().clamp(6, 1000),
                                child: _Liquid(color: s.color),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Glossy reflection along the top of the glass.
              Positioned(
                left: height * 0.3,
                right: height * 0.3,
                top: 1,
                height: (height - 6) * 0.3,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Liquid extends StatelessWidget {
  const _Liquid({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, 0.28)!, color, Color.lerp(color, Colors.black, 0.22)!],
        stops: const [0, 0.55, 1],
      ),
    ),
    child: const SizedBox.expand(),
  );
}
