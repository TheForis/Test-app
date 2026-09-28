import 'package:flutter/foundation.dart';

import '../core/file_category.dart';
import '../core/file_entry.dart';
import '../services/storage/storage_backend.dart';

class CategoryStats {
  const CategoryStats(this.count, this.bytes);
  final int count;
  final int bytes;
}

/// What changed between two scans of the storage.
class ScanReport {
  const ScanReport({
    required this.added,
    required this.removed,
    required this.changed,
    required this.total,
    required this.elapsed,
    required this.full,
    required this.firstScan,
  });

  final int added;
  final int removed;
  final int changed;
  final int total;
  final Duration elapsed;

  /// Every file was re-checked rather than only changed folders.
  final bool full;

  /// There was no earlier index to compare with.
  final bool firstScan;

  bool get hasChanges => added + removed + changed > 0;

  static ScanReport compare(
    List<FileEntry> before,
    List<FileEntry> after, {
    required Duration elapsed,
    required bool full,
    required bool firstScan,
  }) {
    final old = {for (final f in before) f.path: f};
    var added = 0, changed = 0;
    for (final f in after) {
      final o = old[f.path];
      if (o == null) {
        added++;
      } else if (o.size != f.size || o.modified != f.modified) {
        changed++;
      }
    }
    final kept = after.length - added;
    return ScanReport(
      added: added,
      removed: before.length - kept,
      changed: changed,
      total: after.length,
      elapsed: elapsed,
      full: full,
      firstScan: firstScan,
    );
  }
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
  ({bool showHidden, bool full})? _queued;
  ScanReport? _lastReport;
  StorageSpace? _space;
  bool _ready = false;
  List<StorageLocation> _locations = const [];

  List<FileEntry> get files => _files;
  AccessState get access => _access;
  bool get hasAccess => _access == AccessState.granted;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  DateTime? get lastScan => _lastScan;

  /// True once storage access is known and, with access, everything the home
  /// screen draws is loaded: the saved index, device capacity and storage
  /// locations. The app shows its splash until then. Background scans that
  /// bring the index up to date don't affect this.
  bool get ready => _ready;

  /// Internal storage, SD cards and common folders.
  List<StorageLocation> get locations => _locations;

  /// What the most recent scan found.
  ScanReport? get lastReport => _lastReport;

  /// Device capacity, refreshed with every scan. Null on the web.
  StorageSpace? get space => _space;
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
    try {
      _access = await backend.checkAccess();
    } catch (_) {
      _access = AccessState.denied;
    }
    if (hasAccess) await _prepare(showHidden);
    _ready = true;
    notifyListeners();
    // Bring the saved index up to date in the background.
    if (hasAccess) await refresh(showHidden: showHidden);
  }

  /// Loads what the home screen needs to draw in full. Each part is optional:
  /// a failure leaves it empty rather than blocking startup.
  Future<void> _prepare(bool showHidden) async {
    final (cached, space, locations) = await (
      _optional(() => backend.cachedIndex(showHidden: showHidden)),
      _optional(backend.space),
      _optional(backend.locations),
    ).wait;
    if (cached != null && !_loadedOnce) {
      final (files, at) = cached;
      _apply(files);
      _lastScan = at;
      _loadedOnce = true;
    }
    _space ??= space;
    _locations = locations ?? const [];
  }

  static Future<T?> _optional<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  /// Re-reads storage locations (an SD card may have been inserted).
  Future<void> reloadLocations() async {
    final locations = await _optional(backend.locations);
    if (locations == null) return;
    _locations = locations;
    notifyListeners();
  }

  void _apply(List<FileEntry> files) {
    final stats = <FileCategory, List<int>>{};
    for (final f in files) {
      final s = stats.putIfAbsent(f.category, () => [0, 0]);
      s[0]++;
      s[1] += f.size;
    }
    _files = files;
    _stats = {for (final e in stats.entries) e.key: CategoryStats(e.value[0], e.value[1])};
  }

  Future<void> requestAccess({bool showHidden = false}) async {
    final before = _access;
    _access = await backend.requestAccess();
    await _accessChanged(before, showHidden);
  }

  Future<void> recheckAccess({bool showHidden = false}) async {
    final before = _access;
    _access = await backend.checkAccess();
    await _accessChanged(before, showHidden);
  }

  Future<void> _accessChanged(AccessState before, bool showHidden) async {
    if (before == _access) {
      // Still denied, but "permanently" may change which button to show.
      notifyListeners();
      return;
    }
    // Load before notifying, so the home screen appears complete, not blank.
    if (hasAccess) await _prepare(showHidden);
    notifyListeners();
    if (hasAccess) await refresh(showHidden: showHidden);
  }

  /// Brings the index up to date and reports what changed. Unchanged folders
  /// come from the saved index, so a check with no changes is quick; [full]
  /// re-checks every file (Settings → Rescan storage). Returns null when the
  /// request was queued behind a scan already running.
  Future<ScanReport?> refresh({bool showHidden = false, bool full = false}) async {
    if (!hasAccess) return null;
    if (_loading) {
      // Files changed (or a setting did) mid-scan: scan again once this one ends.
      _queued = (showHidden: showHidden, full: full || (_queued?.full ?? false));
      return null;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    final watch = Stopwatch()..start();
    final firstScan = !_loadedOnce;
    ScanReport? report;
    try {
      final (files, space) = await (backend.scanAll(showHidden: showHidden, full: full), backend.space()).wait;
      _space = space;
      report = ScanReport.compare(_files, files, elapsed: watch.elapsed, full: full, firstScan: firstScan);
      _lastReport = report;
      if (report.hasChanges || firstScan) _apply(files);
      _lastScan = DateTime.now();
    } catch (e) {
      _error = 'Could not scan storage: $e';
    } finally {
      _loading = false;
      _loadedOnce = true;
      // Open screens reload only when something actually changed.
      if (report == null || report.hasChanges || firstScan) _generation++;
      notifyListeners();
    }
    final queued = _queued;
    if (queued != null) {
      _queued = null;
      await refresh(showHidden: queued.showHidden, full: queued.full);
    }
    return report;
  }

  /// Call after the app changed files (delete, rename, extract...).
  Future<void> changed({bool showHidden = false}) async {
    _generation++;
    notifyListeners();
    await refresh(showHidden: showHidden);
  }
}
