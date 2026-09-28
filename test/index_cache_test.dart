import 'dart:convert';
import 'dart:io';

import 'package:file_manager/services/storage/index_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late String cache;

  IndexScan scan({bool full = false, bool showHidden = false, Duration every = const Duration(days: 1)}) =>
      IndexScan(roots: [root.path], cachePath: cache, full: full, showHidden: showHidden, fullScanEvery: every);

  Set<String> names(List<dynamic> files) => {for (final f in files) f.name as String};

  setUp(() {
    root = Directory.systemTemp.createTempSync('burrow_index');
    cache = p.join(Directory.systemTemp.createTempSync('burrow_cache').path, 'index.json');
    File(p.join(root.path, 'a.txt')).writeAsStringSync('a');
    Directory(p.join(root.path, 'Photos')).createSync();
    File(p.join(root.path, 'Photos', 'one.jpg')).writeAsStringSync('11');
    File(p.join(root.path, 'Photos', 'two.jpg')).writeAsStringSync('222');
    Directory(p.join(root.path, '.thumbnails')).createSync();
    File(p.join(root.path, '.thumbnails', 't.jpg')).writeAsStringSync('t');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    File(cache).parent.deleteSync(recursive: true);
  });

  test('first scan indexes everything and saves the cache', () {
    final s = scan();
    final files = s.run();
    expect(names(files), {'a.txt', 'one.jpg', 'two.jpg'});
    expect(s.fileStats, 3);
    expect(File(cache).existsSync(), isTrue);
  });

  test('a scan with no changes looks up no files at all', () {
    scan().run();
    final s = scan();
    final files = s.run();
    expect(names(files), {'a.txt', 'one.jpg', 'two.jpg'});
    expect(s.fileStats, 0);
  });

  test('only new files are looked up', () {
    scan().run();
    File(p.join(root.path, 'Photos', 'three.jpg')).writeAsStringSync('3333');
    final s = scan();
    final files = s.run();
    expect(names(files), contains('three.jpg'));
    expect(s.fileStats, 1);
    expect(files.firstWhere((f) => f.name == 'three.jpg').size, 4);
  });

  test('deleted files disappear without looking anything up', () {
    scan().run();
    File(p.join(root.path, 'Photos', 'one.jpg')).deleteSync();
    final s = scan();
    expect(names(s.run()), {'a.txt', 'two.jpg'});
    expect(s.fileStats, 0);
  });

  test('unchanged folders are served from the cache; a full scan re-checks them', () {
    scan().run();
    // Plant an entry only the cache knows about, in a folder that hasn't changed.
    final json = jsonDecode(File(cache).readAsStringSync()) as Map<String, dynamic>;
    final photos = (json['dirs'] as Map<String, dynamic>)[p.join(root.path, 'Photos')] as Map<String, dynamic>;
    (photos['f'] as List<dynamic>).add(['cached-only.jpg', 9, 0]);
    File(cache).writeAsStringSync(jsonEncode(json));

    expect(names(scan().run()), contains('cached-only.jpg'));
    expect(names(scan(full: true).run()), isNot(contains('cached-only.jpg')));
  });

  test('a full scan runs by itself once the cache is old enough', () {
    scan().run();
    final s = scan(every: Duration.zero);
    s.run();
    expect(s.fileStats, 3);
  });

  test('hidden files are included only when shown', () {
    expect(names(scan().run()), isNot(contains('t.jpg')));
    final s = scan(showHidden: true);
    expect(names(s.run()), contains('t.jpg'));
    // Only the hidden folder, which the earlier scan skipped, needed reading.
    expect(s.fileStats, 1);
  });

  test('the saved snapshot can be shown before scanning', () {
    scan().run();
    final snapshot = IndexScan.readSnapshot(cache);
    expect(snapshot, isNotNull);
    expect(names(snapshot!.$1), {'a.txt', 'one.jpg', 'two.jpg'});
  });

  test('a corrupt cache is ignored', () {
    File(cache)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{not json');
    expect(IndexScan.readSnapshot(cache), isNull);
    final s = scan();
    expect(names(s.run()), {'a.txt', 'one.jpg', 'two.jpg'});
    expect(s.fileStats, 3);
  });
}
