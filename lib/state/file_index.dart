import 'package:flutter/foundation.dart';

import '../core/file_category.dart';
import '../core/file_entry.dart';
import '../services/storage/storage_backend.dart';

class CategoryStats {
  const CategoryStats(this.count, this.bytes);
  final int count;
  final int bytes;
}

/// Index of every file on the storage, used for the home cards, recent
/// files, category screens and global search.
class FileIndex extends ChangeNotifier {
  FileIndex(this.backend);

  final StorageBackend backend;

  List<FileEntry> _files = const [];
  Map<FileCategory, CategoryStats> _stats = const {};
  AccessState _access = AccessState.denied;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  DateTime? _lastScan;
  int _generation = 0;

  List<FileEntry> get files => _files;
  AccessState get access => _access;
  bool get hasAccess => _access == AccessState.granted;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  DateTime? get lastScan => _lastScan;
  int get totalBytes => _stats.values.fold(0, (a, s) => a + s.bytes);

  /// Increments on every change to storage so open screens can reload.
  int get generation => _generation;

  CategoryStats statsFor(FileCategory c) => _stats[c] ?? const CategoryStats(0, 0);

  List<FileEntry> byCategory(FileCategory c) => _files.where((f) => f.category == c).toList();

  List<FileEntry> recent({int limit = 30}) {
    final sorted = List.of(_files)..sort((a, b) => b.modified.compareTo(a.modified));
    return sorted.take(limit).toList();
  }

  Future<void> init({bool showHidden = false}) async {
    _access = await backend.checkAccess();
    notifyListeners();
    if (hasAccess) await refresh(showHidden: showHidden);
  }

  Future<void> requestAccess({bool showHidden = false}) async {
    _access = await backend.requestAccess();
    notifyListeners();
    if (hasAccess) await refresh(showHidden: showHidden);
  }

  Future<void> recheckAccess({bool showHidden = false}) async {
    final before = _access;
    _access = await backend.checkAccess();
    if (before != _access) {
      notifyListeners();
      if (hasAccess) await refresh(showHidden: showHidden);
    }
  }

  Future<void> refresh({bool showHidden = false}) async {
    if (!hasAccess || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final files = await backend.scanAll(showHidden: showHidden);
      final stats = <FileCategory, List<int>>{};
      for (final f in files) {
        final s = stats.putIfAbsent(f.category, () => [0, 0]);
        s[0]++;
        s[1] += f.size;
      }
      _files = files;
      _stats = {for (final e in stats.entries) e.key: CategoryStats(e.value[0], e.value[1])};
      _lastScan = DateTime.now();
    } catch (e) {
      _error = 'Could not scan storage: $e';
    } finally {
      _loading = false;
      _loadedOnce = true;
      _generation++;
      notifyListeners();
    }
  }

  /// Call after the app changed files (delete, rename, extract...).
  Future<void> changed({bool showHidden = false}) async {
    _generation++;
    notifyListeners();
    await refresh(showHidden: showHidden);
  }
}
