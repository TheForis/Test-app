import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/sorting.dart';
import '../../state/app_scope.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';
import '../widgets/sort_menu.dart';

enum SizeFilter {
  any('Any size', 0, null),
  small('< 1 MB', 0, 1000 * 1000),
  medium('1 – 100 MB', 1000 * 1000, 100 * 1000 * 1000),
  large('> 100 MB', 100 * 1000 * 1000, null);

  const SizeFilter(this.label, this.min, this.max);
  final String label;
  final int min;
  final int? max;

  bool matches(int size) => size >= min && (max == null || size < max!);
}

enum DateFilter {
  any('Any time', null),
  today('Today', Duration(days: 1)),
  week('Last 7 days', Duration(days: 7)),
  month('Last 30 days', Duration(days: 30)),
  year('Last year', Duration(days: 365));

  const DateFilter(this.label, this.within);
  final String label;
  final Duration? within;

  bool matches(DateTime modified, DateTime now) => within == null || now.difference(modified) <= within!;
}

/// Global search across the whole index with type, size and date filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  ShellController? _shell;
  String _query = '';
  Set<FileCategory> _categories = {};
  SizeFilter _size = SizeFilter.any;
  DateFilter _date = DateFilter.any;
  SortOptions _sort = const SortOptions(field: SortField.name);
  static const _maxResults = 500;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shell?.removeListener(_onShell);
    _shell = ShellScope.of(context)..addListener(_onShell);
  }

  /// Focus the search field whenever the Search tab is opened.
  void _onShell() {
    if (_shell?.tab == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    } else {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _shell?.removeListener(_onShell);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasCriteria =>
      _query.trim().isNotEmpty || _categories.isNotEmpty || _size != SizeFilter.any || _date != DateFilter.any;

  List<FileEntry> _results(List<FileEntry> files) {
    if (!_hasCriteria) return const [];
    final now = DateTime.now();
    final matched = filterEntries(
      files,
      query: _query,
      categories: _categories,
    ).where((f) => _size.matches(f.size) && _date.matches(f.modified, now));
    return sortEntries(matched, _sort);
  }

  void _clear() => setState(() {
    _controller.clear();
    _query = '';
    _categories = {};
    _size = SizeFilter.any;
    _date = DateFilter.any;
  });

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final pad = pagePadding(context);
    return ListenableBuilder(
      listenable: scope.index,
      builder: (context, _) {
        final results = _results(scope.index.files);
        final shown = results.take(_maxResults).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Search')),
          body: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: pad,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by file name',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear',
                              onPressed: () => setState(() {
                                _controller.clear();
                                _query = '';
                              }),
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 12),
                CategoryFilterChips(
                  selected: _categories,
                  onChanged: (c) => setState(() => _categories = c),
                  padding: pad,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: pad,
                  child: Row(
                    children: [
                      _DropdownChip<SizeFilter>(
                        icon: Icons.straighten_rounded,
                        value: _size,
                        values: SizeFilter.values,
                        label: (v) => v.label,
                        active: _size != SizeFilter.any,
                        onChanged: (v) => setState(() => _size = v),
                      ),
                      const SizedBox(width: 8),
                      _DropdownChip<DateFilter>(
                        icon: Icons.calendar_today_rounded,
                        value: _date,
                        values: DateFilter.values,
                        label: (v) => v.label,
                        active: _date != DateFilter.any,
                        onChanged: (v) => setState(() => _date = v),
                      ),
                      const SizedBox(width: 8),
                      SortMenuButton(options: _sort, onChanged: (s) => setState(() => _sort = s)),
                      if (_hasCriteria) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_hasCriteria)
                  Padding(
                    padding: pad.copyWith(top: 12, bottom: 4),
                    child: Text(
                      results.length > _maxResults
                          ? 'Showing $_maxResults of ${results.length} results'
                          : '${results.length} result${results.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                Expanded(
                  child: !_hasCriteria
                      ? EmptyState(
                          icon: Icons.manage_search_rounded,
                          title: 'Find any file',
                          message:
                              'Type a name or pick a type, size or date filter.\n'
                              '${scope.index.files.length} files indexed.',
                        )
                      : shown.isEmpty
                      ? const EmptyState(icon: Icons.search_off_rounded, title: 'No files found')
                      : ListView.builder(
                          padding: pad.copyWith(bottom: 24),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final e = shown[i];
                            return FileListTile(
                              entry: e,
                              subtitle: '${entrySubtitle(e)} • ${scope.backend.nameOf(scope.backend.parentOf(e.path))}',
                              onTap: () => openEntry(context, e, siblings: shown),
                              onLongPress: () => showFileActions(context, e, siblings: shown),
                              onMore: () => showFileActions(context, e, siblings: shown),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  const _DropdownChip({
    required this.icon,
    required this.value,
    required this.values,
    required this.label,
    required this.active,
    required this.onChanged,
  });

  final IconData icon;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final bool active;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final v in values) CheckedPopupMenuItem<T>(value: v, checked: v == value, child: Text(label(v))),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18, color: active ? scheme.onSecondaryContainer : null),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label(value)), const Icon(Icons.arrow_drop_down_rounded, size: 20)],
        ),
        backgroundColor: active ? scheme.secondaryContainer : null,
      ),
    );
  }
}
