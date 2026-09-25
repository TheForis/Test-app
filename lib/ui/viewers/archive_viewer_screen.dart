import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/format.dart';
import '../../services/storage/archive_utils.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';

class _ArchiveItem {
  const _ArchiveItem(this.name, this.size, this.isFile);
  final String name;
  final int size;
  final bool isFile;
}

List<_ArchiveItem> _listArchive((String, Uint8List) input) {
  final archive = decodeArchiveBytes(input.$1, input.$2);
  return [for (final f in archive) _ArchiveItem(f.name, f.size, f.isFile)];
}

/// Shows what is inside a zip / tar / gz archive and extracts it.
class ArchiveViewerScreen extends StatefulWidget {
  const ArchiveViewerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<ArchiveViewerScreen> createState() => _ArchiveViewerScreenState();
}

class _ArchiveViewerScreenState extends State<ArchiveViewerScreen> {
  static const _maxPreviewBytes = 200 * 1024 * 1024;
  Future<List<_ArchiveItem>>? _items;
  bool _extracting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items ??= _load();
  }

  Future<List<_ArchiveItem>> _load() async {
    if (widget.entry.size > _maxPreviewBytes) return const [];
    final bytes = await AppScope.of(context).backend.readBytes(widget.entry.path);
    return compute(_listArchive, (widget.entry.name, bytes));
  }

  Future<void> _extract() async {
    setState(() => _extracting = true);
    await extractEntry(context, widget.entry);
    if (mounted) setState(() => _extracting = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showFileActions(context, widget.entry),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _extracting ? null : _extract,
        icon: _extracting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
            : const Icon(Icons.unarchive_rounded),
        label: Text(_extracting ? 'Extracting…' : 'Extract'),
      ),
      body: FutureBuilder<List<_ArchiveItem>>(
        future: _items,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Cannot read this archive',
              message: '${snap.error}',
              action: OutlinedButton(
                onPressed: () => openExternally(context, widget.entry),
                child: const Text('Open with another app'),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return EmptyState(
              icon: FileCategory.archive.icon,
              title: widget.entry.size > _maxPreviewBytes ? 'Archive too large to preview' : 'Archive is empty',
              message: widget.entry.size > _maxPreviewBytes ? 'You can still extract it.' : null,
            );
          }
          final files = items.where((i) => i.isFile).toList();
          final total = files.fold<int>(0, (a, i) => a + i.size);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Text(
                    '${files.length} files • ${formatBytes(total)} uncompressed',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              final item = items[i - 1];
              final category = item.isFile ? FileCategory.fromExtension(item.name.split('.').last) : null;
              return ListTile(
                leading: Icon(
                  item.isFile ? category!.icon : Icons.folder_rounded,
                  color: item.isFile ? category!.color : scheme.primary,
                ),
                title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: item.isFile ? Text(formatBytes(item.size)) : null,
                dense: true,
              );
            },
          );
        },
      ),
    );
  }
}
