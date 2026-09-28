import 'dart:io' show FileSystemException;

import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/format.dart';
import '../../core/sorting.dart';
import '../../services/opener/external_opener.dart';
import '../../services/storage/storage_backend.dart';
import '../../state/app_scope.dart';
import '../shell.dart';
import '../viewers/archive_viewer_screen.dart';
import '../viewers/audio_player_screen.dart';
import '../viewers/image_viewer_screen.dart';
import '../viewers/pdf_viewer_screen.dart';
import '../viewers/text_viewer_screen.dart';
import '../viewers/video_player_screen.dart';
import 'file_thumb.dart';

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Opens any file: built-in viewers for PDFs, images, text and archives;
/// the package installer for APKs; other apps (or the browser) for the rest.
Future<void> openEntry(BuildContext context, FileEntry entry, {List<FileEntry>? siblings}) async {
  if (entry.isDirectory) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    ShellScope.of(context).openFolder(entry.path);
    return;
  }
  final navigator = Navigator.of(context);
  if (entry.isPdf) {
    navigator.push(MaterialPageRoute(builder: (_) => PdfViewerScreen(entry: entry)));
  } else if (entry.isViewableImage) {
    final images = (siblings ?? [entry]).where((e) => e.isViewableImage).toList();
    final index = images.indexOf(entry);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(images: index < 0 ? [entry] : images, initialIndex: index < 0 ? 0 : index),
      ),
    );
  } else if (entry.isPlayableVideo) {
    navigator.push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(entry: entry)));
  } else if (entry.isPlayableAudio) {
    // The other tracks in the list become the playlist.
    final tracks = (siblings ?? [entry]).where((e) => e.isPlayableAudio).toList();
    final index = tracks.indexOf(entry);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AudioPlayerScreen(tracks: index < 0 ? [entry] : tracks, initialIndex: index < 0 ? 0 : index),
      ),
    );
  } else if (entry.isText) {
    navigator.push(MaterialPageRoute(builder: (_) => TextViewerScreen(entry: entry)));
  } else if (entry.isExtractable) {
    navigator.push(MaterialPageRoute(builder: (_) => ArchiveViewerScreen(entry: entry)));
  } else if (entry.isApk) {
    await installApk(context, entry);
  } else {
    await openExternally(context, entry);
  }
}

Future<void> openExternally(BuildContext context, FileEntry entry) async {
  final backend = AppScope.of(context).backend;
  try {
    final bytes = backend.isDeviceStorage ? null : await backend.readBytes(entry.path);
    final result = await ExternalOpener.open(path: entry.path, name: entry.name, bytes: bytes);
    if (!result.ok && context.mounted) {
      showMessage(context, result.message.isEmpty ? 'Could not open ${entry.name}' : result.message);
    }
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not open ${entry.name}: $e');
  }
}

Future<void> installApk(BuildContext context, FileEntry entry) async {
  final backend = AppScope.of(context).backend;
  if (!backend.canInstallApps) {
    showMessage(context, 'APK files can only be installed on Android devices');
    return;
  }
  final result = await ExternalOpener.installApk(entry.path);
  if (!result.ok && context.mounted) {
    showMessage(
      context,
      result.message,
      action: result.outcome == OpenOutcome.permissionDenied
          ? SnackBarAction(label: 'Settings', onPressed: backend.openAccessSettings)
          : null,
    );
  }
}

Future<void> downloadEntry(BuildContext context, FileEntry entry) async {
  final backend = AppScope.of(context).backend;
  final bytes = await backend.readBytes(entry.path);
  await ExternalOpener.download(name: entry.name, bytes: bytes);
}

/// Runs a file operation, shows errors, and refreshes the index on success.
Future<T?> runFileOp<T>(BuildContext context, Future<T> Function() op, {String? success}) async {
  final scope = AppScope.of(context);
  try {
    final result = await op();
    if (success != null && context.mounted) showMessage(context, success);
    await scope.filesChanged();
    return result;
  } catch (e) {
    if (context.mounted) showMessage(context, friendlyError(e));
    return null;
  }
}

/// Turns low-level exceptions into a sentence a user can act on.
String friendlyError(Object error) {
  if (error is FileSystemException) {
    final os = error.osError?.message.toLowerCase() ?? '';
    if (os.contains('no space')) return 'Not enough storage space';
    if (os.contains('permission') || os.contains('not permitted')) {
      return "Burrow isn't allowed to change this location";
    }
    if (os.contains('read-only')) return 'This storage is read-only';
    return 'Something went wrong: ${error.osError?.message ?? error.message}';
  }
  return '$error';
}

Future<void> extractEntry(BuildContext context, FileEntry entry) async {
  final scope = AppScope.of(context);
  final shell = ShellScope.of(context);
  showMessage(context, 'Extracting ${entry.name}…');
  final dest = await runFileOp(context, () => scope.backend.extract(entry));
  if (dest != null && context.mounted) {
    showMessage(
      context,
      'Extracted to ${scope.backend.nameOf(dest)}',
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          shell.openFolder(dest);
        },
      ),
    );
  }
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
  String label = 'Name',
}) {
  final controller = TextEditingController(text: initial);
  final dot = initial.lastIndexOf('.');
  controller.selection = TextSelection(baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
  String? validate(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter a name';
    if (t.contains('/') || t.contains('\\')) return 'Names cannot contain / or \\';
    if (t == '.' || t == '..') return 'Invalid name';
    // SD cards (FAT/exFAT) reject these characters.
    if (RegExp('[<>:"|?*\x00-\x1F]').hasMatch(t)) return 'Names cannot contain < > : " | ? *';
    if (t.length > 255) return 'Name is too long';
    return null;
  }

  return showDialog<String>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final e = validate(controller.text);
            if (e != null) {
              setState(() => error = e);
              return;
            }
            Navigator.pop(context, controller.text.trim());
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder()),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: submit, child: Text(confirm)),
            ],
          );
        },
      );
    },
  );
}

Future<bool> confirmDelete(BuildContext context, List<FileEntry> entries) async {
  final what = entries.length == 1 ? '"${entries.first.name}"' : '${entries.length} items';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> deleteEntries(BuildContext context, List<FileEntry> entries) async {
  if (entries.isEmpty || !await confirmDelete(context, entries)) return;
  if (!context.mounted) return;
  final backend = AppScope.of(context).backend;
  await runFileOp(context, () async {
    for (final e in entries) {
      await backend.delete(e);
    }
  }, success: entries.length == 1 ? 'Deleted ${entries.first.name}' : 'Deleted ${entries.length} items');
}

Future<void> transferEntries(BuildContext context, List<FileEntry> entries, {required bool move}) async {
  final target = await pickFolder(
    context,
    title: move ? 'Move to' : 'Copy to',
    confirm: move ? 'Move here' : 'Copy here',
  );
  if (target == null || !context.mounted) return;
  final backend = AppScope.of(context).backend;
  await runFileOp(context, () async {
    for (final e in entries) {
      move ? await backend.move(e, target) : await backend.copy(e, target);
    }
  }, success: '${move ? 'Moved' : 'Copied'} ${entries.length == 1 ? entries.first.name : '${entries.length} items'}');
}

Future<void> renameEntry(BuildContext context, FileEntry entry) async {
  final name = await promptText(context, title: 'Rename', confirm: 'Rename', initial: entry.name);
  if (name == null || name == entry.name || !context.mounted) return;
  final backend = AppScope.of(context).backend;
  await runFileOp(context, () => backend.rename(entry, name), success: 'Renamed to $name');
}

void showDetails(BuildContext context, FileEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final rows = <(String, String)>[
        ('Name', entry.name),
        (
          'Type',
          entry.isDirectory
              ? 'Folder'
              : '${entry.extension.isEmpty ? 'File' : entry.extension.toUpperCase()} · ${entry.category.label}',
        ),
        (
          entry.isDirectory ? 'Items' : 'Size',
          entry.isDirectory ? '${entry.size}' : '${formatBytes(entry.size)} (${entry.size} bytes)',
        ),
        ('Modified', formatFullDate(entry.modified)),
        ('Location', entry.path),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FileThumb(entry: entry, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(child: SelectableText(v)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet with every action available for [entry].
Future<void> showFileActions(BuildContext context, FileEntry entry, {List<FileEntry>? siblings}) {
  final backend = AppScope.of(context).backend;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      void run(Future<void> Function() action) {
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: FileThumb(entry: entry, size: 44),
                title: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  entry.isDirectory ? 'Folder' : '${formatBytes(entry.size)} • ${formatDate(entry.modified)}',
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(entry.isDirectory ? Icons.folder_open_rounded : Icons.open_in_new_rounded),
                title: const Text('Open'),
                onTap: () => run(() => openEntry(context, entry, siblings: siblings)),
              ),
              if (entry.isApk && backend.canInstallApps)
                ListTile(
                  leading: Icon(Icons.install_mobile_rounded, color: FileCategory.apk.color),
                  title: const Text('Install app'),
                  onTap: () => run(() => installApk(context, entry)),
                ),
              if (entry.isExtractable)
                ListTile(
                  leading: const Icon(Icons.unarchive_rounded),
                  title: const Text('Extract here'),
                  onTap: () => run(() => extractEntry(context, entry)),
                ),
              if (!entry.isDirectory)
                ListTile(
                  leading: const Icon(Icons.apps_rounded),
                  title: Text(backend.isDeviceStorage ? 'Open with another app' : 'Open in new tab'),
                  onTap: () => run(() => openExternally(context, entry)),
                ),
              if (!entry.isDirectory && !backend.isDeviceStorage)
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download'),
                  onTap: () => run(() => downloadEntry(context, entry)),
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename'),
                onTap: () => run(() => renameEntry(context, entry)),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy to…'),
                onTap: () => run(() => transferEntries(context, [entry], move: false)),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('Move to…'),
                onTap: () => run(() => transferEntries(context, [entry], move: true)),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Details'),
                onTap: () => run(() async => showDetails(context, entry)),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(sheetContext).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () => run(() => deleteEntries(context, [entry])),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dialog for choosing a destination folder.
Future<String?> pickFolder(BuildContext context, {required String title, required String confirm}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderPickerDialog(title: title, confirm: confirm),
  );
}

class _FolderPickerDialog extends StatefulWidget {
  const _FolderPickerDialog({required this.title, required this.confirm});
  final String title;
  final String confirm;

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  List<StorageLocation> _roots = const [];
  String? _path;
  List<FileEntry>? _folders;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_path == null) {
      final backend = AppScope.of(context).backend;
      backend.locations().then((locations) async {
        final roots = locations.where((l) => l.isRoot).toList();
        if (!mounted) return;
        setState(() => _roots = roots);
        _load(roots.isNotEmpty ? roots.first.path : await backend.rootPath());
      });
    }
  }

  Future<void> _load(String path) async {
    final scope = AppScope.of(context);
    setState(() {
      _path = path;
      _folders = null;
      _error = null;
    });
    try {
      final all = await scope.backend.list(path, showHidden: scope.settings.showHidden);
      if (!mounted || _path != path) return;
      setState(() => _folders = sortEntries(all.where((e) => e.isDirectory), const SortOptions()));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = AppScope.of(context).backend;
    final atRoot = _path == null || _roots.any((r) => r.path == _path);
    // Fits phones held sideways, where there is little vertical room.
    final height = (MediaQuery.sizeOf(context).height * 0.5).clamp(200.0, 420.0);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: 420,
        height: height,
        child: Column(
          children: [
            if (_roots.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in _roots)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: ChoiceChip(
                          avatar: Icon(r.icon, size: 18),
                          label: Text(r.name),
                          selected: _path != null && (_path == r.path || _path!.startsWith('${r.path}/')),
                          onSelected: (_) => _load(r.path),
                        ),
                      ),
                  ],
                ),
              ),
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Up',
                onPressed: atRoot ? null : () => _load(backend.parentOf(_path!)),
              ),
              title: Text(_path == null ? '' : backend.nameOf(_path!), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'New folder',
                onPressed: _path == null
                    ? null
                    : () async {
                        final name = await promptText(context, title: 'New folder', confirm: 'Create');
                        if (name == null || !mounted) return;
                        try {
                          await backend.createFolder(_path!, name);
                          _load(_path!);
                        } catch (e) {
                          if (mounted) setState(() => _error = '$e');
                        }
                      },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : _folders == null
                  ? const Center(child: CircularProgressIndicator())
                  : _folders!.isEmpty
                  ? const Center(child: Text('No subfolders'))
                  : ListView.builder(
                      itemCount: _folders!.length,
                      itemBuilder: (context, i) {
                        final f = _folders![i];
                        return ListTile(
                          leading: const Icon(Icons.folder_rounded),
                          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _load(f.path),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _path == null ? null : () => Navigator.pop(context, _path),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
