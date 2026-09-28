import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/file_entry.dart';
import 'archive_utils.dart';
import 'index_cache.dart';
import 'memory_backend.dart' show FileSystemError;
import 'storage_backend.dart';

/// Real device storage. On Android this is the shared storage
/// (/storage/emulated/0 plus SD cards); on iOS it is the app's Documents
/// folder, which is shared with the Files app.
class IoStorageBackend implements StorageBackend {
  String? _root;
  List<String> _extraRoots = const [];

  @override
  bool get isDeviceStorage => true;
  @override
  bool get supportsImport => Platform.isIOS;
  @override
  bool get canInstallApps => Platform.isAndroid;

  /// "All files access" only exists on Android 11+; older versions report
  /// it as restricted and use the classic storage permission instead.
  Future<bool> _usesLegacyStorage() async => (await Permission.manageExternalStorage.status).isRestricted;

  @override
  Future<AccessState> checkAccess() async {
    if (!Platform.isAndroid) return AccessState.granted;
    final granted = await _usesLegacyStorage()
        ? await Permission.storage.isGranted
        : await Permission.manageExternalStorage.isGranted;
    return granted ? AccessState.granted : AccessState.denied;
  }

  @override
  Future<AccessState> requestAccess() async {
    if (!Platform.isAndroid) return AccessState.granted;
    if (await _usesLegacyStorage()) {
      final status = await Permission.storage.request();
      if (status.isGranted) return AccessState.granted;
      return status.isPermanentlyDenied ? AccessState.permanentlyDenied : AccessState.denied;
    }
    // Opens the system "All files access" page for this app.
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted ? AccessState.granted : AccessState.denied;
  }

  @override
  Future<void> openAccessSettings() => openAppSettings();

  @override
  Future<String> rootPath() async {
    if (_root != null) return _root!;
    if (Platform.isAndroid) {
      String root = '/storage/emulated/0';
      final extras = <String>[];
      try {
        final dirs = await getExternalStorageDirectories() ?? const [];
        for (var i = 0; i < dirs.length; i++) {
          final path = dirs[i].path;
          final idx = path.indexOf('/Android/');
          final base = idx > 0 ? path.substring(0, idx) : path;
          if (i == 0) {
            root = base;
          } else {
            extras.add(base);
          }
        }
      } catch (_) {}
      _extraRoots = extras;
      _root = root;
    } else {
      _root = (await getApplicationDocumentsDirectory()).path;
    }
    return _root!;
  }

  static const _storageChannel = MethodChannel('burrow/storage');

  @override
  Future<StorageSpace?> space() async {
    try {
      final result = await _storageChannel.invokeMapMethod<String, int>('space', {'path': await rootPath()});
      final total = result?['total'], free = result?['free'];
      if (total == null || free == null || total <= 0) return null;
      return StorageSpace(total: total, free: free);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<StorageLocation>> locations() async {
    final root = await rootPath();
    if (!Platform.isAndroid) {
      return [StorageLocation(name: 'On my device', path: root, icon: Icons.phone_iphone_rounded, isRoot: true)];
    }
    final result = <StorageLocation>[
      StorageLocation(name: 'Internal storage', path: root, icon: Icons.smartphone_rounded, isRoot: true),
      for (final (i, extra) in _extraRoots.indexed)
        StorageLocation(
          name: _extraRoots.length == 1 ? 'SD card' : 'SD card ${i + 1}',
          path: extra,
          icon: Icons.sd_card_rounded,
          isRoot: true,
        ),
    ];
    const common = {
      'Download': Icons.download_rounded,
      'DCIM': Icons.camera_alt_rounded,
      'Pictures': Icons.image_rounded,
      'Documents': Icons.description_rounded,
      'Music': Icons.library_music_rounded,
      'Movies': Icons.movie_rounded,
    };
    for (final e in common.entries) {
      final path = p.join(root, e.key);
      if (await Directory(path).exists()) {
        result.add(StorageLocation(name: e.key == 'Download' ? 'Downloads' : e.key, path: path, icon: e.value));
      }
    }
    return result;
  }

  @override
  Future<List<FileEntry>> list(String directory, {bool showHidden = false}) async {
    final dir = Directory(directory);
    if (!await dir.exists()) throw FileSystemError('Folder not found');
    final result = <FileEntry>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (!showHidden && name.startsWith('.')) continue;
        final entry = await _toEntry(entity, showHidden: showHidden);
        if (entry != null) result.add(entry);
      }
    } on FileSystemException catch (e) {
      throw FileSystemError('Cannot open this folder: ${e.osError?.message ?? e.message}');
    }
    return result;
  }

  /// For folders, `size` is the number of children, counting hidden ones only
  /// when [showHidden] is set so it matches what opening the folder shows.
  static Future<FileEntry?> _toEntry(FileSystemEntity entity, {bool showHidden = true}) async {
    try {
      final stat = await entity.stat();
      final isDir = stat.type == FileSystemEntityType.directory;
      var size = stat.size;
      if (isDir) {
        size = 0;
        try {
          size = await Directory(entity.path)
              .list(followLinks: false)
              .where((c) => showHidden || !p.basename(c.path).startsWith('.'))
              .length;
        } catch (_) {}
      }
      return FileEntry(
        path: entity.path,
        name: p.basename(entity.path),
        isDirectory: isDir,
        size: size,
        modified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FileEntry>> scanAll({bool showHidden = false, bool full = false}) async {
    final roots = [await rootPath(), ..._extraRoots];
    final sdRoots = _extraRoots;
    final cache = await _indexCachePath();
    return Isolate.run(
      () => IndexScan(roots: roots, sdRoots: sdRoots, cachePath: cache, showHidden: showHidden, full: full).run(),
    );
  }

  @override
  Future<(List<FileEntry>, DateTime)?> cachedIndex({bool showHidden = false}) async {
    final cache = await _indexCachePath();
    return Isolate.run(() => IndexScan.readSnapshot(cache, showHidden: showHidden));
  }

  /// In the app's private storage: not visible to the user or other apps.
  Future<String> _indexCachePath() async => p.join((await getApplicationSupportDirectory()).path, 'index-v1.json');

  @override
  Future<FileEntry?> stat(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    return _toEntry(type == FileSystemEntityType.directory ? Directory(path) : File(path));
  }

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<Uint8List> readHead(String path, int maxBytes) async {
    final file = await File(path).open();
    try {
      return await file.read(maxBytes);
    } finally {
      await file.close();
    }
  }

  /// Compressed tarballs must be fully decompressed in memory to be listed.
  static const _maxInMemoryPreview = 64 * 1024 * 1024;

  @override
  Future<List<ArchiveListing>> listArchiveEntries(FileEntry archive) {
    final path = archive.path;
    final name = archive.name.toLowerCase();
    final size = archive.size;
    // Everything happens in the isolate so large archives never cross into
    // (or get copied by) the UI isolate.
    return Isolate.run(() {
      if (name.endsWith('.zip') || name.endsWith('.jar') || name.endsWith('.apk')) {
        final input = InputFileStream(path);
        try {
          return listArchive(ZipDecoder().decodeStream(input));
        } finally {
          input.closeSync();
        }
      }
      if (name.endsWith('.tar')) {
        final input = InputFileStream(path);
        try {
          return listArchive(TarDecoder().decodeStream(input));
        } finally {
          input.closeSync();
        }
      }
      if (size > _maxInMemoryPreview) throw const ArchiveTooLargeError();
      return listArchive(decodeArchiveBytes(p.basename(path), File(path).readAsBytesSync()));
    });
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> createFolder(String parent, String name) async {
    final dir = Directory(p.join(parent, name));
    if (await dir.exists() || await File(dir.path).exists()) throw FileSystemError('"$name" already exists');
    await dir.create(recursive: true);
  }

  @override
  Future<void> delete(FileEntry entry) async {
    try {
      if (entry.isDirectory) {
        await Directory(entry.path).delete(recursive: true);
      } else {
        await File(entry.path).delete();
      }
    } on FileSystemException catch (e) {
      throw FileSystemError('Could not delete ${entry.name}: ${e.osError?.message ?? e.message}');
    }
  }

  @override
  Future<FileEntry> rename(FileEntry entry, String newName) async {
    final target = p.join(p.dirname(entry.path), newName);
    // Android shared storage ignores case, so "a.jpg" -> "A.jpg" finds itself.
    final caseOnly = p.normalize(target).toLowerCase() == p.normalize(entry.path).toLowerCase();
    if (!caseOnly && await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
      throw FileSystemError('"$newName" already exists');
    }
    final entity = entry.isDirectory ? Directory(entry.path) : File(entry.path);
    try {
      if (caseOnly) {
        // Some file systems treat a case-only rename as a no-op; go via a temporary name.
        final temp = await entity.rename('$target.burrow-rename');
        return (await _toEntry(await temp.rename(target)))!;
      }
      return (await _toEntry(await entity.rename(target)))!;
    } on FileSystemException catch (e) {
      throw FileSystemError('Could not rename ${entry.name}: ${e.osError?.message ?? e.message}');
    }
  }

  Future<String> _uniquePath(String dir, String name) async {
    var candidate = p.join(dir, name);
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var i = 1;
    while (await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound) {
      candidate = p.join(dir, '$base ($i)$ext');
      i++;
    }
    return candidate;
  }

  Future<void> _copyTree(String from, String to) async {
    final type = await FileSystemEntity.type(from, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(to).create(recursive: true);
      await for (final child in Directory(from).list(followLinks: false)) {
        await _copyTree(child.path, p.join(to, p.basename(child.path)));
      }
    } else if (type == FileSystemEntityType.file) {
      await File(from).copy(to);
    }
  }

  @override
  Future<FileEntry> copy(FileEntry entry, String targetDirectory) async {
    if (entry.isDirectory && (p.isWithin(entry.path, targetDirectory) || entry.path == targetDirectory)) {
      throw FileSystemError('Cannot copy a folder into itself');
    }
    final target = await _uniquePath(targetDirectory, entry.name);
    await _copyTree(entry.path, target);
    return (await stat(target))!;
  }

  @override
  Future<FileEntry> move(FileEntry entry, String targetDirectory) async {
    if (p.dirname(entry.path) == targetDirectory) return entry;
    if (entry.isDirectory && (p.isWithin(entry.path, targetDirectory) || entry.path == targetDirectory)) {
      throw FileSystemError('Cannot move a folder into itself');
    }
    final target = await _uniquePath(targetDirectory, entry.name);
    try {
      final entity = entry.isDirectory ? Directory(entry.path) : File(entry.path);
      await entity.rename(target);
    } on FileSystemException {
      // Rename fails across volumes (e.g. internal -> SD card): copy + delete.
      await _copyTree(entry.path, target);
      await delete(entry);
    }
    return (await stat(target))!;
  }

  @override
  Future<String> extract(FileEntry archive) async {
    final dest = await _uniquePath(p.dirname(archive.path), archiveBaseName(archive.name));
    final source = archive.path;
    final name = archive.name.toLowerCase();
    final streamFromDisk =
        name.endsWith('.zip') ||
        name.endsWith('.jar') ||
        name.contains('.tar') ||
        name.endsWith('.tgz') ||
        name.endsWith('.tbz2') ||
        name.endsWith('.txz');
    await Isolate.run(() async {
      if (streamFromDisk) {
        // Streams from disk and refuses entries that escape [dest].
        await extractFileToDisk(source, dest);
      } else {
        final decoded = decodeArchiveBytes(p.basename(source), File(source).readAsBytesSync());
        Directory(dest).createSync(recursive: true);
        for (final f in decoded) {
          final rel = safeArchivePath(f.name);
          if (rel == null || !f.isFile) continue;
          final out = File(p.join(dest, rel));
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(f.readBytes() ?? const []);
        }
      }
    });
    return dest;
  }

  @override
  Future<int> importFiles(String targetDirectory) async {
    final picked = await FilePicker.pickFiles();
    var count = 0;
    for (final file in picked) {
      final target = await _uniquePath(targetDirectory, file.name);
      final path = file.path;
      if (path != null) {
        await File(path).copy(target);
      } else {
        await File(target).writeAsBytes(await file.readAsBytes());
      }
      count++;
    }
    return count;
  }

  @override
  String join(String a, String b) => p.join(a, b);
  @override
  String parentOf(String path) => p.dirname(path);
  @override
  String nameOf(String path) => p.basename(path);
}
