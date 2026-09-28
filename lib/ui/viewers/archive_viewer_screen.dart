import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/format.dart';
import '../../services/storage/archive_utils.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';

/// Shows what is inside a zip / tar / gz archive and extracts it.
class ArchiveViewerScreen extends StatefulWidget {
  const ArchiveViewerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<ArchiveViewerScreen> createState() => _ArchiveViewerScreenState();
}

class _ArchiveViewerScreenState extends State<ArchiveViewerScreen> {
  Future<List<ArchiveListing>>? _items;
  bool _tooLarge = false;
  bool _extracting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items ??= _load();
  }

  Future<List<ArchiveListing>> _load() async {
    try {
      return await AppScope.of(context).backend.listArchiveEntries(widget.entry);
    } on ArchiveTooLargeError {
      _tooLarge = true;
      return const [];
    }
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
      body: FutureBuilder<List<ArchiveListing>>(
        future: _items,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Cannot read this archive',
              message: 'It may be damaged or use an unsupported format.',
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
              title: _tooLarge ? 'Archive too large to preview' : 'Archive is empty',
              message: _tooLarge ? 'You can still extract it.' : null,
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
