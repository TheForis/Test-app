import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';

/// Read-only viewer for text, code, JSON, CSV, Markdown, logs...
class TextViewerScreen extends StatefulWidget {
  const TextViewerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  static const _maxBytes = 1024 * 1024;

  /// Lines per rendered block: big files are laid out lazily, block by block.
  static const _linesPerBlock = 80;
  Future<(List<String>, int, bool)>? _text;
  double _fontSize = 14;
  bool _wrap = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= _load();
  }

  /// Returns the text split into blocks, the longest line length and whether
  /// the file was cut off.
  Future<(List<String>, int, bool)> _load() async {
    final bytes = await AppScope.of(context).backend.readHead(widget.entry.path, _maxBytes);
    final truncated = widget.entry.size > bytes.length;
    var text = utf8.decode(bytes, allowMalformed: true);
    if (widget.entry.extension == 'json' && !truncated) {
      try {
        text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
      } catch (_) {}
    }
    final lines = const LineSplitter().convert(text);
    final longest = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    final blocks = [
      for (var i = 0; i < lines.length; i += _linesPerBlock)
        lines.sublist(i, (i + _linesPerBlock).clamp(0, lines.length)).join('\n'),
    ];
    return (blocks, longest, truncated);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: _fontSize > 9 ? () => setState(() => _fontSize -= 1) : null,
          ),
          IconButton(
            tooltip: 'Larger text',
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: _fontSize < 28 ? () => setState(() => _fontSize += 1) : null,
          ),
          IconButton(
            tooltip: _wrap ? 'Disable word wrap' : 'Enable word wrap',
            icon: Icon(_wrap ? Icons.wrap_text_rounded : Icons.notes_rounded),
            onPressed: () => setState(() => _wrap = !_wrap),
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showFileActions(context, widget.entry),
          ),
        ],
      ),
      body: FutureBuilder<(List<String>, int, bool)>(
        future: _text,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Cannot read this file',
              action: OutlinedButton(
                onPressed: () => openExternally(context, widget.entry),
                child: const Text('Open with another app'),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (blocks, longest, truncated) = snap.data!;
          final style = TextStyle(fontFamily: 'monospace', fontSize: _fontSize, height: 1.45, color: scheme.onSurface);
          if (blocks.isEmpty) {
            return Center(
              child: Text('(empty file)', style: TextStyle(color: scheme.onSurfaceVariant)),
            );
          }
          return Column(
            children: [
              if (truncated)
                MaterialBanner(
                  content: const Text('Large file: showing the first 1 MB.'),
                  actions: [
                    TextButton(
                      onPressed: () => openExternally(context, widget.entry),
                      child: const Text('Open elsewhere'),
                    ),
                  ],
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    Widget list(double width) => SizedBox(
                      width: width,
                      height: c.maxHeight,
                      child: Scrollbar(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: blocks.length,
                          itemBuilder: (context, i) => Text(blocks[i], style: style, softWrap: _wrap),
                        ),
                      ),
                    );
                    // Monospace glyphs are about 0.62em wide; very long lines are clipped.
                    final contentWidth = (longest.clamp(0, 4000) * _fontSize * 0.62) + 32;
                    return SelectionArea(
                      child: _wrap || contentWidth <= c.maxWidth
                          ? list(c.maxWidth)
                          : SingleChildScrollView(scrollDirection: Axis.horizontal, child: list(contentWidth)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
