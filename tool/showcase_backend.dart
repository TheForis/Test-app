import 'dart:math';
import 'dart:typed_data';

import 'package:file_manager/core/file_entry.dart';
import 'package:file_manager/services/storage/archive_utils.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/services/storage/storage_backend.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// A realistic, well-used 128 GB Android phone for store screenshots. Only
/// file metadata exists; nothing is stored, so thumbnails fall back to badges.
class ShowcaseBackend extends MemoryStorageBackend {
  ShowcaseBackend() {
    _generate();
  }

  static const _gb = 1000 * 1000 * 1000;
  static const _mb = 1000 * 1000;
  static const _kb = 1000;

  final _files = <FileEntry>[];
  final _now = DateTime.now();

  @override
  bool get isDeviceStorage => true;
  @override
  bool get supportsImport => false;
  @override
  bool get canInstallApps => true;

  @override
  Future<StorageSpace?> space() async => const StorageSpace(total: 119 * _gb, free: 58 * _gb + 400 * _mb);

  @override
  Future<String> rootPath() async => '/';

  @override
  Future<List<StorageLocation>> locations() async => const [
    StorageLocation(name: 'Internal storage', path: '/', icon: Icons.smartphone_rounded, isRoot: true),
    StorageLocation(name: 'Downloads', path: '/Download', icon: Icons.download_rounded),
    StorageLocation(name: 'DCIM', path: '/DCIM', icon: Icons.camera_alt_rounded),
    StorageLocation(name: 'Documents', path: '/Documents', icon: Icons.description_rounded),
    StorageLocation(name: 'Music', path: '/Music', icon: Icons.library_music_rounded),
  ];

  @override
  Future<List<FileEntry>> scanAll({bool showHidden = false, bool full = false}) async => List.of(_files);

  @override
  Future<List<FileEntry>> list(String directory, {bool showHidden = false}) async {
    final dir = directory.isEmpty ? '/' : directory;
    final prefix = dir == '/' ? '/' : '$dir/';
    final folders = <String, List<FileEntry>>{};
    final direct = <FileEntry>[];
    for (final f in _files) {
      if (!f.path.startsWith(prefix)) continue;
      final rest = f.path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0) {
        direct.add(f);
      } else {
        folders.putIfAbsent(rest.substring(0, slash), () => []).add(f);
      }
    }
    if (dir == '/') {
      for (final empty in const ['Alarms', 'Android', 'Ringtones']) {
        folders.putIfAbsent(empty, () => []);
      }
    }
    return [
      for (final MapEntry(key: name, value: children) in folders.entries)
        FileEntry(
          path: '$prefix$name',
          name: name,
          isDirectory: true,
          size: children.map((c) => c.path.substring(prefix.length + name.length + 1).split('/').first).toSet().length,
          modified: children.isEmpty
              ? _now.subtract(const Duration(days: 300))
              : children.map((c) => c.modified).reduce((a, b) => a.isAfter(b) ? a : b),
        ),
      ...direct,
    ];
  }

  @override
  Future<FileEntry?> stat(String path) async => _files.where((f) => f.path == path).firstOrNull;

  @override
  Future<Uint8List> readBytes(String path) async => throw FileSystemError('Showcase data has no contents');

  @override
  Future<List<ArchiveListing>> listArchiveEntries(FileEntry archive) async => [
    for (final (i, name) in const [
      'Ohrid/IMG_20260814_0931.jpg',
      'Ohrid/IMG_20260814_1012.jpg',
      'Ohrid/IMG_20260814_1147.jpg',
      'Ohrid/IMG_20260815_1820.jpg',
      'Ohrid/IMG_20260815_1904.jpg',
      'Ohrid/VID_20260815_1930.mp4',
      'Mavrovo/IMG_20260817_0815.jpg',
      'Mavrovo/IMG_20260817_0902.jpg',
      'Mavrovo/IMG_20260817_1140.jpg',
      'Mavrovo/Panorama_20260817.jpg',
      'Skopje/IMG_20260820_2031.jpg',
      'Skopje/IMG_20260820_2115.jpg',
      'README.txt',
    ].indexed)
      ArchiveListing(
        name,
        name.endsWith('.mp4') ? 148 * _mb : (name.endsWith('.txt') ? 2 * _kb : (3 + i % 4) * _mb),
        true,
      ),
  ];

  void _add(String path, int size, Duration ago) => _files.add(
    FileEntry(path: path, name: p.posix.basename(path), isDirectory: false, size: size, modified: _now.subtract(ago)),
  );

  void _generate() {
    final rnd = Random(42);
    Duration hours(num h) => Duration(minutes: (h * 60).round());
    String stamp(Duration ago) {
      final t = _now.subtract(ago);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
    }

    // Recent downloads, newest first: these fill "Recent files".
    const downloads = [
      ('Q3 Financial Report.pdf', 2400 * _kb, 0.4),
      ('Holiday photos.zip', 312 * _mb, 2.5),
      ('Invoice INV-2026-0918.pdf', 184 * _kb, 20.0),
      ('Boarding pass SKP-VIE.pdf', 96 * _kb, 26.0),
      ('Design Matters - Episode 142.mp3', 58 * _mb, 31.0),
      ('Wallpaper 4K.png', 8200 * _kb, 70.0),
      ('Budget 2026.xlsx', 64 * _kb, 90.0),
      ('Project brief.docx', 1100 * _kb, 120.0),
      ('Screen recording.mp4', 142 * _mb, 150.0),
      ('Backup 2026-09.tar.gz', 1400 * _mb, 200.0),
      ('Weather Radar 5.2.apk', 38 * _mb, 260.0),
      ('Podcast Player 3.1.apk', 24 * _mb, 400.0),
      ('Trip to Ohrid - itinerary.pdf', 740 * _kb, 500.0),
      ('Trip photos - selection.zip', 96 * _mb, 520.0),
      ('Contacts export.csv', 38 * _kb, 700.0),
    ];
    for (final (name, size, h) in downloads) {
      _add('/Download/$name', size, hours(h));
    }

    const documents = [
      ('Rental contract.pdf', 1800 * _kb),
      ('Tax return 2025.pdf', 920 * _kb),
      ('Pitch deck.pptx', 14 * _mb),
      ('Meeting notes.md', 12 * _kb),
      ('Recipes.docx', 2100 * _kb),
      ('Reading list.txt', 4 * _kb),
      ('Road trip checklist.pdf', 310 * _kb),
      ('Warranty - washing machine.pdf', 640 * _kb),
    ];
    for (final (i, (name, size)) in documents.indexed) {
      _add('/Documents/$name', size, hours(30 + i * 97));
    }

    // Camera: photos and a few videos across the last year.
    for (var i = 0; i < 1400; i++) {
      final ago = hours(6 + i * 6.1 + rnd.nextDouble() * 4);
      _add('/DCIM/Camera/IMG_${stamp(ago)}.jpg', 2500 * _kb + rnd.nextInt(3800 * _kb), ago);
    }
    for (var i = 0; i < 48; i++) {
      final ago = hours(40 + i * 170 + rnd.nextDouble() * 20);
      _add('/DCIM/Camera/VID_${stamp(ago)}.mp4', 60 * _mb + rnd.nextInt(700 * _mb), ago);
    }
    for (var i = 0; i < 180; i++) {
      final ago = hours(3 + i * 44.0);
      _add('/Pictures/Screenshots/Screenshot_${stamp(ago)}.png', 400 * _kb + rnd.nextInt(1600 * _kb), ago);
    }

    const movies = [
      ('Weekend in Ohrid.mp4', 1800 * _mb),
      ('Family dinner.mp4', 640 * _mb),
      ('Concert - front row.mp4', 1200 * _mb),
      ('Drone flight over Matka.mp4', 2300 * _mb),
    ];
    for (final (i, (name, size)) in movies.indexed) {
      _add('/Movies/$name', size, hours(300 + i * 400));
    }

    const artists = ['Northern Lights', 'The Vinyl Club', 'Mila Rose', 'Echo Park', 'Sunday Drive', 'Blue Harbor'];
    const titles = ['Midnight City', 'Golden Hour', 'Slow Motion', 'Paper Planes', 'Wildfire', 'Neon Rain', 'Horizon'];
    for (var i = 0; i < 230; i++) {
      final name = '${artists[i % artists.length]} - ${titles[(i * 5) % titles.length]} ${i ~/ 42 + 1}.mp3';
      _add('/Music/$name', 3500 * _kb + rnd.nextInt(8 * _mb), hours(800 + i * 30.0));
    }
    for (var i = 0; i < 26; i++) {
      _add('/Podcasts/Episode ${140 - i}.mp3', 40 * _mb + rnd.nextInt(40 * _mb), hours(31 + i * 168.0));
    }
  }
}
