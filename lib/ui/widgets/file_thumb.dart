import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../services/image_source.dart';
import '../../state/app_scope.dart';

/// Colored icon badge for a file, or a real thumbnail for images.
class FileThumb extends StatelessWidget {
  const FileThumb({super.key, required this.entry, this.size = 48, this.radius = 14});

  final FileEntry entry;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (entry.isDirectory) {
      return _Badge(
        size: size,
        radius: radius,
        background: scheme.primaryContainer,
        child: Icon(Icons.folder_rounded, color: scheme.onPrimaryContainer, size: size * 0.52),
      );
    }
    final category = entry.category;
    final fallback = _Badge(
      size: size,
      radius: radius,
      background: category.color.withValues(alpha: 0.16),
      child: entry.isPdf
          ? Text(
              'PDF',
              style: TextStyle(color: category.color, fontWeight: FontWeight.w800, fontSize: size * 0.24),
            )
          : Icon(category.icon, color: category.color, size: size * 0.5),
    );
    if (!entry.isViewableImage || entry.size > 30 * 1024 * 1024) return fallback;
    return _ImageThumb(entry: entry, size: size, radius: radius, fallback: fallback);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.size, required this.radius, required this.background, required this.child});
  final double size;
  final double radius;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
    child: child,
  );
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({required this.entry, required this.size, required this.radius, required this.fallback});
  final FileEntry entry;
  final double size;
  final double radius;
  final Widget fallback;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  Future<ImageProvider>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= imageProviderFor(AppScope.of(context).backend, widget.entry);
  }

  @override
  void didUpdateWidget(covariant _ImageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path || oldWidget.entry.modified != widget.entry.modified) {
      _future = imageProviderFor(AppScope.of(context).backend, widget.entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return FutureBuilder<ImageProvider>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return widget.fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Image(
            image: ResizeImage(snap.data!, width: (widget.size * dpr).round(), policy: ResizeImagePolicy.fit),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
        );
      },
    );
  }
}

extension FileCategoryX on FileCategory {
  LinearGradient get linearGradient =>
      LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight);
}
