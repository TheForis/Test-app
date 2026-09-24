import 'file_category.dart';
import 'file_entry.dart';

enum SortField {
  name('Name'),
  date('Date'),
  size('Size'),
  type('Type');

  const SortField(this.label);
  final String label;
}

class SortOptions {
  const SortOptions({this.field = SortField.name, this.ascending = true, this.foldersFirst = true});

  final SortField field;
  final bool ascending;
  final bool foldersFirst;

  SortOptions copyWith({SortField? field, bool? ascending}) =>
      SortOptions(field: field ?? this.field, ascending: ascending ?? this.ascending, foldersFirst: foldersFirst);

  /// Sensible default direction per field: A→Z, newest first, largest first.
  static SortOptions defaultFor(SortField field) =>
      SortOptions(field: field, ascending: field == SortField.name || field == SortField.type);
}

List<FileEntry> sortEntries(Iterable<FileEntry> input, SortOptions options) {
  final list = List<FileEntry>.of(input);
  int compare(FileEntry a, FileEntry b) {
    if (options.foldersFirst && a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    int result;
    switch (options.field) {
      case SortField.name:
        result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortField.date:
        result = a.modified.compareTo(b.modified);
      case SortField.size:
        result = a.size.compareTo(b.size);
      case SortField.type:
        result = a.extension.compareTo(b.extension);
        if (result == 0) result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    if (result == 0 && options.field != SortField.name) {
      result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    return options.ascending ? result : -result;
  }

  list.sort(compare);
  return list;
}

/// Applies a text query and an optional category filter.
List<FileEntry> filterEntries(Iterable<FileEntry> input, {String query = '', Set<FileCategory> categories = const {}}) {
  final q = query.trim().toLowerCase();
  return input.where((e) {
    if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) return false;
    if (categories.isNotEmpty) {
      if (e.isDirectory) return false;
      if (!categories.contains(e.category)) return false;
    }
    return true;
  }).toList();
}
