import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_manager/services/storage/io_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  final fs = IoStorageBackend();

  setUp(() => dir = Directory.systemTemp.createTempSync('burrow_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('readHead reads only the start of a file', () async {
    final file = File('${dir.path}/log.txt')..writeAsStringSync('0123456789');
    expect(utf8.decode(await fs.readHead(file.path, 4)), '0123');
  });

  test('zip entries are listed by streaming from disk', () async {
    final zip = ZipEncoder().encode(Archive()..add(ArchiveFile.bytes('a/b.txt', utf8.encode('hello'))));
    File('${dir.path}/pack.zip').writeAsBytesSync(zip);
    final entry = (await fs.stat('${dir.path}/pack.zip'))!;
    final listing = await fs.listArchiveEntries(entry);
    expect(listing.single.name, 'a/b.txt');
  });

  test('case-only rename works', () async {
    File('${dir.path}/photo.jpg').writeAsStringSync('x');
    final entry = (await fs.stat('${dir.path}/photo.jpg'))!;
    final renamed = await fs.rename(entry, 'Photo.jpg');
    expect(renamed.name, 'Photo.jpg');
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['Photo.jpg']);
  });

  test('rename refuses to overwrite another file', () async {
    File('${dir.path}/a.txt').writeAsStringSync('a');
    File('${dir.path}/b.txt').writeAsStringSync('b');
    final a = (await fs.stat('${dir.path}/a.txt'))!;
    expect(() => fs.rename(a, 'b.txt'), throwsA(isA<Exception>()));
  });
}
