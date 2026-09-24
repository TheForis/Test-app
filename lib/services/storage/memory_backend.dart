import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/file_entry.dart';
import 'archive_utils.dart';
import 'sample_files.dart';
import 'storage_backend.dart';

class _Node {
  _Node.dir(this.modified) : bytes = null;
  _Node.file(Uint8List this.bytes, this.modified);

  Uint8List? bytes;
  DateTime modified;
  bool get isDirectory => bytes == null;
}

/// In-memory file system used on the web, where the browser does not give
/// apps access to the device's folders. Users bring files in with "Import"
/// and everything else (browse, search, sort, unzip, view) works the same.
class MemoryStorageBackend implements StorageBackend {
  MemoryStorageBackend({bool seedSamples = false}) {
    _nodes['/'] = _Node.dir(DateTime.now());
    for (final folder in _defaultFolders) {
      _nodes['/$folder'] = _Node.dir(DateTime.now());
    }
    if (seedSamples) _seed();
  }

  static const _defaultFolders = ['Documents', 'Downloads', 'Pictures', 'Music', 'Videos'];
  static final _ctx = p.posix;

  final Map<String, _Node> _nodes = {};

  @override
  bool get isDeviceStorage => false;
  @override
  bool get supportsImport => true;
  @override
  bool get canInstallApps => false;

  @override
  Future<AccessState> checkAccess() async => AccessState.granted;
  @override
  Future<AccessState> requestAccess() async => AccessState.granted;
  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<String> rootPath() async => '/';

  @override
  Future<List<StorageLocation>> locations() async => [
    const StorageLocation(name: 'My files', path: '/', icon: Icons.cloud_rounded, isRoot: true),
    const StorageLocation(name: 'Downloads', path: '/Downloads', icon: Icons.download_rounded),
    const StorageLocation(name: 'Documents', path: '/Documents', icon: Icons.description_rounded),
    const StorageLocation(name: 'Pictures', path: '/Pictures', icon: Icons.image_rounded),
  ];

  String _norm(String path) => _ctx.normalize(path.isEmpty ? '/' : path);

  FileEntry _entry(String path, _Node node) => FileEntry(
    path: path,
    name: path == '/' ? 'My files' : _ctx.basename(path),
    isDirectory: node.isDirectory,
    size: node.isDirectory ? _childCount(path) : node.bytes!.length,
    modified: node.modified,
  );

  int _childCount(String dir) => _nodes.keys.where((k) => k != dir && _ctx.dirname(k) == dir).length;

  @override
  Future<List<FileEntry>> list(String directory, {bool showHidden = false}) async {
    final dir = _norm(directory);
    final node = _nodes[dir];
    if (node == null || !node.isDirectory) throw FileSystemError('Folder not found: $dir');
    return [
      for (final e in _nodes.entries)
        if (e.key != dir && _ctx.dirname(e.key) == dir && (showHidden || !_ctx.basename(e.key).startsWith('.')))
          _entry(e.key, e.value),
    ];
  }

  @override
  Future<List<FileEntry>> scanAll({bool showHidden = false}) async => [
    for (final e in _nodes.entries)
      if (!e.value.isDirectory && (showHidden || !e.key.split('/').any((s) => s.startsWith('.'))))
        _entry(e.key, e.value),
  ];

  @override
  Future<FileEntry?> stat(String path) async {
    final n = _norm(path);
    final node = _nodes[n];
    return node == null ? null : _entry(n, node);
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final node = _nodes[_norm(path)];
    if (node == null || node.isDirectory) throw FileSystemError('File not found: $path');
    return node.bytes!;
  }

  void _ensureDir(String dir) {
    final n = _norm(dir);
    if (_nodes[n]?.isDirectory ?? false) return;
    if (_nodes.containsKey(n)) throw FileSystemError('A file named ${_ctx.basename(n)} already exists');
    _ensureDir(_ctx.dirname(n));
    _nodes[n] = _Node.dir(DateTime.now());
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final n = _norm(path);
    _ensureDir(_ctx.dirname(n));
    _nodes[n] = _Node.file(bytes, DateTime.now());
    _nodes[_ctx.dirname(n)]!.modified = DateTime.now();
  }

  @override
  Future<void> createFolder(String parent, String name) async {
    final path = _ctx.join(_norm(parent), name);
    if (_nodes.containsKey(path)) throw FileSystemError('"$name" already exists');
    _ensureDir(path);
  }

  Iterable<String> _subtree(String path) =>
      _nodes.keys.where((k) => k == path || k.startsWith(path == '/' ? '/' : '$path/')).toList();

  @override
  Future<void> delete(FileEntry entry) async {
    final n = _norm(entry.path);
    if (n == '/') throw FileSystemError('Cannot delete the root folder');
    for (final k in _subtree(n)) {
      _nodes.remove(k);
    }
  }

  void _moveTree(String from, String to, {required bool keepSource}) {
    for (final k in _subtree(from)) {
      final node = _nodes[k]!;
      final target = to + k.substring(from.length);
      _nodes[target] = node.isDirectory
          ? _Node.dir(DateTime.now())
          : _Node.file(node.bytes!, keepSource ? DateTime.now() : node.modified);
      if (!keepSource) _nodes.remove(k);
    }
  }

  @override
  Future<FileEntry> rename(FileEntry entry, String newName) async {
    final from = _norm(entry.path);
    final to = _ctx.join(_ctx.dirname(from), newName);
    if (_nodes.containsKey(to)) throw FileSystemError('"$newName" already exists');
    _moveTree(from, to, keepSource: false);
    return _entry(to, _nodes[to]!);
  }

  String _uniquePath(String dir, String name) {
    var candidate = _ctx.join(dir, name);
    final ext = _ctx.extension(name);
    final base = _ctx.basenameWithoutExtension(name);
    var i = 1;
    while (_nodes.containsKey(candidate)) {
      candidate = _ctx.join(dir, '$base ($i)$ext');
      i++;
    }
    return candidate;
  }

  @override
  Future<FileEntry> copy(FileEntry entry, String targetDirectory) async {
    final from = _norm(entry.path);
    final dir = _norm(targetDirectory);
    if (entry.isDirectory && (dir == from || dir.startsWith('$from/'))) {
      throw FileSystemError('Cannot copy a folder into itself');
    }
    final to = _uniquePath(dir, entry.name);
    _moveTree(from, to, keepSource: true);
    return _entry(to, _nodes[to]!);
  }

  @override
  Future<FileEntry> move(FileEntry entry, String targetDirectory) async {
    final from = _norm(entry.path);
    final dir = _norm(targetDirectory);
    if (_ctx.dirname(from) == dir) return entry;
    if (entry.isDirectory && (dir == from || dir.startsWith('$from/'))) {
      throw FileSystemError('Cannot move a folder into itself');
    }
    final to = _uniquePath(dir, entry.name);
    _moveTree(from, to, keepSource: false);
    return _entry(to, _nodes[to]!);
  }

  @override
  Future<String> extract(FileEntry archive) async {
    final bytes = await readBytes(archive.path);
    final decoded = decodeArchiveBytes(archive.name, bytes);
    final dest = _uniquePath(_ctx.dirname(_norm(archive.path)), archiveBaseName(archive.name));
    _ensureDir(dest);
    for (final file in decoded) {
      final rel = safeArchivePath(file.name);
      if (rel == null || file.isSymbolicLink) continue;
      final target = _ctx.join(dest, rel);
      if (file.isFile) {
        await writeBytes(target, file.readBytes() ?? Uint8List(0));
      } else {
        _ensureDir(target);
      }
    }
    return dest;
  }

  @override
  Future<int> importFiles(String targetDirectory) async {
    final picked = await FilePicker.pickFiles();
    var count = 0;
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      await writeBytes(_uniquePath(_norm(targetDirectory), file.name), bytes);
      count++;
    }
    return count;
  }

  @override
  String join(String a, String b) => _ctx.join(a, b);
  @override
  String parentOf(String path) => _ctx.dirname(_norm(path));
  @override
  String nameOf(String path) => _norm(path) == '/' ? 'My files' : _ctx.basename(path);

  void _seed() {
    final now = DateTime.now();
    void put(String path, Uint8List bytes, Duration age) {
      final n = _norm(path);
      _ensureDir(_ctx.dirname(n));
      _nodes[n] = _Node.file(bytes, now.subtract(age));
    }

    put('/Documents/Welcome.txt', utf8.encode(welcomeText), const Duration(minutes: 3));
    put('/Documents/Getting started.pdf', buildSamplePdf(), const Duration(hours: 2));
    put('/Documents/notes.md', utf8.encode(sampleMarkdown), const Duration(days: 1));
    put('/Downloads/data.json', utf8.encode(sampleJson), const Duration(days: 2));
    final zip = Archive()
      ..add(ArchiveFile.string('readme.txt', 'Files inside a zip archive.\nTap "Extract" to unzip them.'))
      ..add(ArchiveFile.string('docs/todo.md', '# Todo\n- Try sorting by size\n- Try the search filters\n'))
      ..add(ArchiveFile.string('docs/report.csv', 'month,value\nJan,12\nFeb,19\nMar,7\n'));
    put('/Downloads/sample-archive.zip', ZipEncoder().encodeBytes(zip), const Duration(days: 3));
    put('/Pictures/gradient.bmp', buildSampleBitmap(), const Duration(days: 5));
  }
}

class FileSystemError implements Exception {
  FileSystemError(this.message);
  final String message;
  @override
  String toString() => message;
}
