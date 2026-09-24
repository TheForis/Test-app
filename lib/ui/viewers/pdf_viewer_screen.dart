import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/file_entry.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';

/// Built-in PDF viewer (pdfium based) for Android, iOS and web.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _controller = PdfViewerController();
  Future<Uint8List>? _bytes;
  int? _page;
  int _pageCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backend = AppScope.of(context).backend;
    if (!backend.isDeviceStorage) _bytes ??= backend.readBytes(widget.entry.path);
  }

  Future<String?> _askPassword() =>
      promptText(context, title: 'Password protected PDF', confirm: 'Open', label: 'Password');

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(maxScale: 8),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      onViewerReady: (document, controller) => setState(() {
        _pageCount = document.pages.length;
        _page = controller.pageNumber ?? 1;
      }),
      onPageChanged: (page) => setState(() => _page = page),
      errorBannerBuilder: (context, error, stack, ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not open this PDF.\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_pageCount > 0) Text('Page ${_page ?? 1} of $_pageCount', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            onPressed: (_page ?? 1) > 1 ? () => _controller.goToPage(pageNumber: (_page ?? 1) - 1) : null,
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: _pageCount > 0 && (_page ?? 1) < _pageCount
                ? () => _controller.goToPage(pageNumber: (_page ?? 1) + 1)
                : null,
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showFileActions(context, widget.entry),
          ),
        ],
      ),
      body: _bytes == null
          ? PdfViewer.file(widget.entry.path, controller: _controller, params: params, passwordProvider: _askPassword)
          : FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Could not read file: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return PdfViewer.data(
                  snap.data!,
                  sourceName: widget.entry.path,
                  controller: _controller,
                  params: params,
                  passwordProvider: _askPassword,
                );
              },
            ),
    );
  }
}
