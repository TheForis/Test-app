import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_manager/services/storage/archive_utils.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late MemoryStorageBackend fs;
  setUp(() => fs = MemoryStorageBackend());

  test('create, list, rename, copy, move and delete', () async {
    await fs.createFolder('/', 'Work');
    await fs.writeBytes('/Work/a.txt', text('hello'));
    var list = await fs.list('/Work');
    expect(list.single.name, 'a.txt');
    expect(list.single.size, 5);

    final renamed = await fs.rename(list.single, 'b.txt');
    expect(renamed.path, '/Work/b.txt');

    final copy = await fs.copy(renamed, '/Work');
    expect(copy.name, 'b (1).txt');

    final work = (await fs.stat('/Work'))!;
    final moved = await fs.move(work, '/Documents');
    expect(moved.path, '/Documents/Work');
    expect((await fs.list('/Documents/Work')).length, 2);
    expect(await fs.stat('/Work'), isNull);

    await fs.delete(moved);
    expect(await fs.stat('/Documents/Work/b.txt'), isNull);
  });

  test('cannot move a folder into itself', () async {
    await fs.createFolder('/', 'A');
    await fs.createFolder('/A', 'B');
    final a = (await fs.stat('/A'))!;
    await expectLater(fs.move(a, '/A/B'), throwsA(isA<FileSystemError>()));
  });

  test('extracts zip archives and blocks path traversal', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('readme.txt', 'hi'))
      ..add(ArchiveFile.string('docs/x.md', '# x'))
      ..add(ArchiveFile.string('../evil.txt', 'nope'));
    await fs.writeBytes('/Downloads/pack.zip', ZipEncoder().encodeBytes(archive));
    final dest = await fs.extract((await fs.stat('/Downloads/pack.zip'))!);
    expect(dest, '/Downloads/pack');
    expect(utf8.decode(await fs.readBytes('/Downloads/pack/docs/x.md')), '# x');
    expect(await fs.stat('/Downloads/evil.txt'), isNull);
    expect(await fs.stat('/evil.txt'), isNull);
  });

  test('scanAll returns every file and seeded samples decode', () async {
    final seeded = MemoryStorageBackend(seedSamples: true);
    final all = await seeded.scanAll();
    expect(all.any((e) => e.name == 'Getting started.pdf'), isTrue);
    final zip = all.firstWhere((e) => e.name == 'sample-archive.zip');
    final decoded = decodeArchiveBytes(zip.name, await seeded.readBytes(zip.path));
    expect(decoded.files.where((f) => f.isFile).length, 3);
    final pdf = await seeded.readBytes('/Documents/Getting started.pdf');
    expect(latin1.decode(pdf.sublist(0, 8)), '%PDF-1.4');
  });

  test('safeArchivePath', () {
    expect(safeArchivePath('a/./b/c.txt'), 'a/b/c.txt');
    expect(safeArchivePath('../x'), isNull);
    expect(safeArchivePath('/abs/x'), 'abs/x');
    expect(archiveBaseName('photos.tar.gz'), 'photos');
  });
}
