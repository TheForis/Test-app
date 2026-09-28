import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../core/format.dart';
import '../../services/image_source.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';

/// Swipeable, zoomable image gallery.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.images, this.initialIndex = 0});

  final List<FileEntry> images;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _chrome = true;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length) return;
    _pages.animateToPage(next, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.images[_index];
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _chrome
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${_index + 1} / ${widget.images.length} • ${formatBytes(entry.size)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Details',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => showDetails(context, entry),
                ),
                IconButton(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => showFileActions(context, entry),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => setState(() => _chrome = !_chrome),
              child: _ZoomableImage(entry: widget.images[i], onZoomChanged: (z) => setState(() => _zoomed = z)),
            ),
          ),
          if (wide && _chrome && _index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filledTonal(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left_rounded)),
              ),
            ),
          if (wide && _chrome && _index < widget.images.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filledTonal(onPressed: () => _go(1), icon: const Icon(Icons.chevron_right_rounded)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.entry, required this.onZoomChanged});
  final FileEntry entry;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transform = TransformationController();
  Future<ImageProvider>? _image;
  TapDownDetails? _doubleTap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _image ??= imageProviderFor(AppScope.of(context).backend, widget.entry);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed) {
      _transform.value = Matrix4.identity();
    } else if (_doubleTap != null) {
      final p = _doubleTap!.localPosition;
      _transform.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
    widget.onZoomChanged(!zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _image,
      builder: (context, snap) {
        if (snap.hasError) return _error();
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
        return GestureDetector(
          onDoubleTapDown: (d) => _doubleTap = d,
          onDoubleTap: _toggleZoom,
          child: InteractiveViewer(
            transformationController: _transform,
            maxScale: 8,
            onInteractionEnd: (_) => widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
            child: SizedBox.expand(
              child: Image(
                // Decoding a 200 MP photo at full size needs ~800 MB. Twice the
                // screen resolution keeps zoom sharp at a fraction of that.
                image: ResizeImage(
                  snap.data!,
                  width: _decodeWidth(context),
                  height: _decodeWidth(context),
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _error(),
              ),
            ),
          ),
        );
      },
    );
  }

  static int _decodeWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final longest = size.longestSide * MediaQuery.devicePixelRatioOf(context) * 2;
    return longest.clamp(1024, 4096).round();
  }

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 12),
        const Text('Cannot display this image', style: TextStyle(color: Colors.white70)),
        TextButton(onPressed: () => openExternally(context, widget.entry), child: const Text('Open with another app')),
      ],
    ),
  );
}
