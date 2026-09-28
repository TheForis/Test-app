import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_manager/core/file_entry.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets a test hold a scan open while files change underneath it.
class _SlowBackend extends MemoryStorageBackend {
  Completer<void>? gate;
  (List<FileEntry>, DateTime)? snapshot;

  @override
  Future<(List<FileEntry>, DateTime)?> cachedIndex({bool showHidden = false}) async => snapshot;

  @override
  Future<List<FileEntry>> scanAll({bool showHidden = false, bool full = false}) async {
    final result = await super.scanAll(showHidden: showHidden, full: full);
    await gate?.future;
    return result;
  }
}

void main() {
  test('a refresh requested during a scan is not lost', () async {
    final fs = _SlowBackend();
    final index = FileIndex(fs);
    await index.init();
    expect(index.files, isEmpty);

    fs.gate = Completer();
    final first = index.refresh();
    await fs.writeBytes('/Documents/new.txt', Uint8List.fromList(utf8.encode('hi')));
    await index.refresh(); // Arrives mid-scan: must be queued, not dropped.
    fs.gate!.complete();
    fs.gate = null;
    await first;

    expect(index.files.map((f) => f.name), contains('new.txt'));
  });

  test('refresh reports what changed, and nothing when nothing did', () async {
    final fs = _SlowBackend();
    final index = FileIndex(fs);
    await index.init();
    await fs.writeBytes('/Documents/a.txt', Uint8List.fromList(utf8.encode('a')));
    await fs.writeBytes('/Documents/b.txt', Uint8List.fromList(utf8.encode('b')));
    expect((await index.refresh())!.added, 2);

    final generation = index.generation;
    final quiet = (await index.refresh())!;
    expect(quiet.hasChanges, isFalse);
    // Open screens aren't reloaded when nothing changed.
    expect(index.generation, generation);

    await fs.writeBytes('/Documents/a.txt', Uint8List.fromList(utf8.encode('longer')));
    await fs.delete((await fs.stat('/Documents/b.txt'))!);
    final report = (await index.refresh())!;
    expect((report.added, report.removed, report.changed), (0, 1, 1));
  });

  test('the saved index is shown before the background check finishes', () async {
    final fs = _SlowBackend()
      ..snapshot = (
        [FileEntry(path: '/Music/song.mp3', name: 'song.mp3', isDirectory: false, size: 5, modified: DateTime(2026))],
        DateTime(2026),
      )
      ..gate = Completer();
    final index = FileIndex(fs);
    final init = index.init();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(index.files.single.name, 'song.mp3');
    expect(index.loadedOnce, isTrue);
    expect(index.loading, isTrue); // still checking in the background
    fs.gate!.complete();
    await init;
    expect(index.loading, isFalse);
    // The real storage has no song.mp3, so the check removed it.
    expect(index.lastReport!.removed, 1);
  });
}
