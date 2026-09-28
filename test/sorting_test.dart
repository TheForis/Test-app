import 'package:file_manager/services/storage/storage_backend.dart';
import 'package:file_manager/core/file_category.dart';
import 'package:file_manager/core/file_entry.dart';
import 'package:file_manager/core/format.dart';
import 'package:file_manager/core/sorting.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry f(String name, int size, int day, {bool dir = false}) =>
    FileEntry(path: '/$name', name: name, isDirectory: dir, size: size, modified: DateTime(2026, 1, day));

void main() {
  final files = [
    f('b.pdf', 300, 3),
    f('A.jpg', 100, 1),
    f('c.apk', 200, 2),
    f('Folder', 5, 9, dir: true),
    f('d.zip', 50, 5),
  ];

  test('sort by name keeps folders first, case-insensitive', () {
    final sorted = sortEntries(files, const SortOptions());
    expect(sorted.map((e) => e.name), ['Folder', 'A.jpg', 'b.pdf', 'c.apk', 'd.zip']);
  });

  test('sort by size descending', () {
    final sorted = sortEntries(files, const SortOptions(field: SortField.size, ascending: false));
    expect(sorted.skip(1).map((e) => e.name), ['b.pdf', 'c.apk', 'A.jpg', 'd.zip']);
  });

  test('sort by date newest first', () {
    final sorted = sortEntries(files, SortOptions.defaultFor(SortField.date));
    expect(sorted.skip(1).first.name, 'd.zip');
  });

  test('filter by query and category', () {
    expect(filterEntries(files, query: 'B.P').map((e) => e.name), ['b.pdf']);
    expect(filterEntries(files, categories: {FileCategory.apk, FileCategory.archive}).map((e) => e.name), [
      'c.apk',
      'd.zip',
    ]);
  });

  test('categories and capabilities from extensions', () {
    expect(f('x.PDF', 1, 1).category, FileCategory.document);
    expect(f('x.PDF', 1, 1).isPdf, isTrue);
    expect(f('game.apk', 1, 1).isApk, isTrue);
    expect(f('a.tar.gz', 1, 1).isExtractable, isTrue);
    expect(f('movie.mkv', 1, 1).category, FileCategory.video);
    expect(f('.hidden', 1, 1).extension, '');
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1500), '1.5 KB');
    expect(formatBytes(5 * 1000 * 1000), '5.0 MB');
    expect(formatBytes(47200000000), '47.2 GB');
    expect(formatCapacity(128000000000), '128 GB');
  });

  test('advertised capacity rounds up to the marketed size', () {
    const gb = 1000 * 1000 * 1000;
    expect(const StorageSpace(total: 110 * gb, free: 0).advertised, 128 * gb);
    expect(const StorageSpace(total: 238 * gb, free: 0).advertised, 256 * gb);
    expect(const StorageSpace(total: 64 * gb, free: 0).advertised, 64 * gb);
  });
}
