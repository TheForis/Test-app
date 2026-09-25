import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';

/// Read-only viewer for text, code, JSON, CSV, Markdown, logs...
class TextViewerScreen extends StatefulWidget {
  const TextViewerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  static const _maxBytes = 2 * 1024 * 1024;
  Future<(String, bool)>? _text;
  double _fontSize = 14;
  bool _wrap = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= _load();
  }

  Future<(String, bool)> _load() async {
    final bytes = await AppScope.of(context).backend.readBytes(widget.entry.path);
    final truncated = bytes.length > _maxBytes;
    final slice = truncated ? bytes.sublist(0, _maxBytes) : bytes;
    var text = utf8.decode(slice, allowMalformed: true);
    if (widget.entry.extension == 'json') {
      try {
        text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
      } catch (_) {}
    }
    return (text, truncated);
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
      body: FutureBuilder<(String, bool)>(
        future: _text,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not read file: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (text, truncated) = snap.data!;
          final body = SelectableText(
            text.isEmpty ? '(empty file)' : text,
            style: TextStyle(fontFamily: 'monospace', fontSize: _fontSize, height: 1.45, color: scheme.onSurface),
          );
          return Column(
            children: [
              if (truncated)
                MaterialBanner(
                  content: const Text('Large file: showing the first 2 MB.'),
                  actions: [
                    TextButton(
                      onPressed: () => openExternally(context, widget.entry),
                      child: const Text('Open elsewhere'),
                    ),
                  ],
                ),
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _wrap
                        ? SizedBox(width: double.infinity, child: body)
                        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: body),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
