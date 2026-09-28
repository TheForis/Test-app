import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/file_entry.dart';

/// Incremental storage scanner with an on-disk cache.
///
/// Walking a phone with 200 GB of files means a `stat` call per file, which
/// takes minutes. Instead, every scan saves each folder's modified time and
/// its file list. The next scan still visits every folder, but:
///
/// * a folder whose modified time is unchanged is reused as-is, without
///   listing or `stat`-ing anything inside it (the OS updates a folder's time
///   whenever a file is added, removed or renamed in it);
/// * a changed folder is listed, but files already known are reused and only
///   new ones are `stat`-ed.
///
/// Folders on SD cards are always listed, because FAT/exFAT don't reliably
/// update folder times. A file edited in place doesn't touch its folder's
/// time, so a [full] scan (forced, or at least once a day) re-checks everything.
///
/// Runs inside a background isolate; the cache file is read and written there
/// so large indexes never pass through the UI isolate.
class IndexScan {
  IndexScan({
    required this.roots,
    required this.cachePath,
    this.sdRoots = const [],
    this.showHidden = false,
    this.full = false,
    this.maxFiles = 150000,
    this.fullScanEvery = const Duration(hours: 24),
  });

  final List<String> roots;
  final List<String> sdRoots;
  final String cachePath;
  final bool showHidden;
  final bool full;
  final int maxFiles;
  final Duration fullScanEvery;

  static const _version = 1;

  /// Number of `stat` calls made on files by the last [run] (for tests).
  int fileStats = 0;

  /// Returns every indexed file and saves the cache.
  List<FileEntry> run() {
    final old = _readCache(cachePath);
    final now = DateTime.now();
    final fullAt = old == null ? null : DateTime.fromMillisecondsSinceEpoch(old['fullAt'] as int? ?? 0);
    final doFull = full || fullAt == null || now.difference(fullAt) > fullScanEvery;
    final oldDirs = doFull ? const <String, dynamic>{} : (old!['dirs'] as Map<String, dynamic>? ?? const {});

    final dirs = <String, Map<String, dynamic>>{};
    final result = <FileEntry>[];
    final queue = <String>[...roots];
    while (queue.isNotEmpty && result.length < maxFiles) {
      final dir = queue.removeLast();
      if (_isPrivateAppFolder(dir)) continue;
      final FileStat stat;
      try {
        stat = FileStat.statSync(dir);
      } catch (_) {
        continue;
      }
      if (stat.type != FileSystemEntityType.directory) continue;
      final mtime = stat.modified.millisecondsSinceEpoch;
      final cached = oldDirs[dir] as Map<String, dynamic>?;
      final onSd = sdRoots.any((r) => dir == r || p.isWithin(r, dir));

      List<List<dynamic>> files;
      List<String> subdirs;
      final reusable =
          cached != null &&
          cached['m'] == mtime &&
          // A cache made with hidden files shown can serve a scan without them.
          (cached['h'] == showHidden || cached['h'] == true) &&
          !onSd;
      if (reusable) {
        files = [
          for (final f in cached['f'] as List<dynamic>)
            if (showHidden || !(f[0] as String).startsWith('.')) f as List<dynamic>,
        ];
        subdirs = [
          for (final d in cached['d'] as List<dynamic>)
            if (showHidden || !(d as String).startsWith('.')) d as String,
        ];
      } else {
        final known = <String, List<dynamic>>{
          if (cached != null)
            for (final f in cached['f'] as List<dynamic>) (f as List<dynamic>)[0] as String: f,
        };
        files = [];
        subdirs = [];
        List<FileSystemEntity> children;
        try {
          children = Directory(dir).listSync(followLinks: false);
        } catch (_) {
          continue;
        }
        for (final child in children) {
          final name = p.basename(child.path);
          if (!showHidden && name.startsWith('.')) continue;
          if (child is Directory) {
            subdirs.add(name);
          } else if (child is File) {
            final reuse = known[name];
            if (reuse != null) {
              files.add(reuse);
              continue;
            }
            try {
              fileStats++;
              final s = child.statSync();
              files.add([name, s.size, s.modified.millisecondsSinceEpoch]);
            } catch (_) {}
          }
        }
      }

      dirs[dir] = {'m': mtime, 'h': showHidden, 'f': files, 'd': subdirs};
      for (final f in files) {
        result.add(_entry(dir, f));
      }
      for (final d in subdirs) {
        queue.add(p.join(dir, d));
      }
    }

    _writeCache(cachePath, {
      'v': _version,
      'at': now.millisecondsSinceEpoch,
      'fullAt': doFull ? now.millisecondsSinceEpoch : fullAt.millisecondsSinceEpoch,
      'dirs': dirs,
    });
    return result;
  }

  /// The files from the last saved scan and when it ran, or null if there is
  /// no usable cache. Used to show the home screen instantly on launch.
  static (List<FileEntry>, DateTime)? readSnapshot(String cachePath, {bool showHidden = false}) {
    final cache = _readCache(cachePath);
    if (cache == null) return null;
    final dirs = cache['dirs'] as Map<String, dynamic>? ?? const {};
    final result = <FileEntry>[];
    for (final MapEntry(key: dir, value: record) in dirs.entries) {
      // Hidden folders only exist in caches made with hidden files shown.
      if (!showHidden && p.split(dir).any((s) => s.startsWith('.'))) continue;
      for (final f in (record as Map<String, dynamic>)['f'] as List<dynamic>) {
        final file = f as List<dynamic>;
        if (!showHidden && (file[0] as String).startsWith('.')) continue;
        result.add(_entry(dir, file));
      }
    }
    return (result, DateTime.fromMillisecondsSinceEpoch(cache['at'] as int? ?? 0));
  }

  static FileEntry _entry(String dir, List<dynamic> f) => FileEntry(
    path: p.join(dir, f[0] as String),
    name: f[0] as String,
    isDirectory: false,
    size: f[1] as int,
    modified: DateTime.fromMillisecondsSinceEpoch(f[2] as int),
  );

  /// Android/data and Android/obb belong to other apps and can't be read.
  static bool _isPrivateAppFolder(String dir) {
    final name = p.basename(dir);
    return (name == 'data' || name == 'obb') && p.basename(p.dirname(dir)) == 'Android';
  }

  static Map<String, dynamic>? _readCache(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic> || json['v'] != _version) return null;
      return json;
    } catch (_) {
      // Corrupt or unreadable: behave as if there were no cache.
      return null;
    }
  }

  static void _writeCache(String path, Map<String, dynamic> data) {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      // Write to a temporary file first so a crash never leaves half a cache.
      final temp = File('$path.tmp')..writeAsStringSync(jsonEncode(data), flush: true);
      temp.renameSync(path);
    } catch (_) {}
  }
}
