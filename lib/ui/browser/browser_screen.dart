import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/sorting.dart';
import '../../services/storage/storage_backend.dart';
import '../../state/app_scope.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';
import '../widgets/sort_menu.dart';

/// Folder browser with breadcrumbs, search, filters, sorting, list/grid
/// views and multi-select.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  String? _root;
  String? _path;
  List<FileEntry> _entries = const [];
  List<StorageLocation> _locations = const [];
  bool _loading = true;
  String? _error;
  SortOptions _sort = const SortOptions();
  Set<FileCategory> _filter = {};
  String _query = '';
  bool _searching = false;
  final Set<FileEntry> _selected = {};
  final _searchController = TextEditingController();
  late ShellController _shell;
  late AppScope _scope;
  int _seenGeneration = -1;

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _shell = ShellScope.of(context);
    _shell.browserBack = _goBack;
    _shell.removeListener(_onShell);
    _shell.addListener(_onShell);
    _scope.index.removeListener(_onIndex);
    _scope.index.addListener(_onIndex);
    if (_root == null) _init();
  }

  @override
  void dispose() {
    _shell.removeListener(_onShell);
    _scope.index.removeListener(_onIndex);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!_scope.index.hasAccess) {
      setState(() => _loading = false);
      return;
    }
    _root = await _scope.backend.rootPath();
    _locations = await _scope.backend.locations();
    final pending = _shell.takePendingPath();
    await _load(pending ?? _root!);
  }

  void _onShell() {
    final pending = _shell.takePendingPath();
    if (pending != null) {
      if (_root == null) {
        _init().then((_) => _load(pending));
      } else {
        _load(pending);
      }
    }
  }

  void _onIndex() {
    final index = _scope.index;
    if (_root == null && index.hasAccess) {
      _init();
      return;
    }
    if (index.generation != _seenGeneration && _path != null) {
      _seenGeneration = index.generation;
      _load(_path!, quiet: true);
    }
  }

  Future<void> _load(String path, {bool quiet = false}) async {
    setState(() {
      if (path != _path) {
        _selected.clear();
        _query = '';
        _searchController.clear();
        _searching = false;
      }
      _path = path;
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      final entries = await _scope.backend.list(path, showHidden: _scope.settings.showHidden);
      if (!mounted || _path != path) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _selected.removeWhere((e) => !entries.contains(e));
      });
    } catch (e) {
      if (!mounted || _path != path) return;
      setState(() {
        _entries = const [];
        _loading = false;
        _error = '$e';
      });
    }
  }

  bool get _atRoot => _path == null || _locations.any((l) => l.isRoot && l.path == _path) || _path == _root;

  bool _goBack() {
    if (_selectionMode) {
      setState(_selected.clear);
      return true;
    }
    if (_searching) {
      setState(() {
        _searching = false;
        _query = '';
        _searchController.clear();
      });
      return true;
    }
    if (!_atRoot && _path != null) {
      _load(_scope.backend.parentOf(_path!));
      return true;
    }
    return false;
  }

  List<FileEntry> get _visible => sortEntries(filterEntries(_entries, query: _query, categories: _filter), _sort);

  void _tap(FileEntry e, List<FileEntry> visible) {
    if (_selectionMode) {
      setState(() => _selected.contains(e) ? _selected.remove(e) : _selected.add(e));
    } else if (e.isDirectory) {
      _load(e.path);
    } else {
      openEntry(context, e, siblings: visible);
    }
  }

  void _longPress(FileEntry e) => setState(() => _selected.add(e));

  Future<void> _newFolder() async {
    final name = await promptText(context, title: 'New folder', confirm: 'Create');
    if (name == null || !mounted || _path == null) return;
    await runFileOp(context, () => _scope.backend.createFolder(_path!, name), success: 'Created $name');
  }

  Future<void> _import() async {
    if (_path == null) return;
    final count = await runFileOp(context, () => _scope.backend.importFiles(_path!));
    if (count != null && count > 0 && mounted) showMessage(context, 'Imported $count file${count == 1 ? '' : 's'}');
  }

  /// Breadcrumb segments from the nearest storage root to the current folder.
  List<(String, String)> _crumbs() {
    final path = _path;
    if (path == null) return const [];
    final backend = _scope.backend;
    final roots = _locations.where((l) => l.isRoot).toList()..sort((a, b) => b.path.length.compareTo(a.path.length));
    final root = roots
        .where((r) => path == r.path || path.startsWith(r.path.endsWith('/') ? r.path : '${r.path}/'))
        .firstOrNull;
    final crumbs = <(String, String)>[];
    var current = path;
    while (true) {
      if (root != null && current == root.path) {
        crumbs.add((root.name, current));
        break;
      }
      crumbs.add((backend.nameOf(current), current));
      final parent = backend.parentOf(current);
      if (parent == current) break;
      current = parent;
    }
    return crumbs.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _scope.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final visible = _visible;
        final grid = settings.gridView;
        final pad = pagePadding(context);
        return Scaffold(
          appBar: _selectionMode ? _selectionBar(visible) : _normalBar(grid),
          floatingActionButton: _selectionMode || _path == null
              ? null
              : (_scope.backend.supportsImport
                    ? FloatingActionButton.extended(
                        onPressed: _import,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Import'),
                      )
                    : FloatingActionButton(
                        onPressed: _newFolder,
                        tooltip: 'New folder',
                        child: const Icon(Icons.create_new_folder_rounded),
                      )),
          body: !_scope.index.hasAccess
              ? EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Storage access needed',
                  message: 'Grant access to browse your files.',
                  action: FilledButton(
                    onPressed: () => _scope.index.requestAccess(showHidden: settings.showHidden),
                    child: const Text('Grant access'),
                  ),
                )
              : Column(
                  children: [
                    _breadcrumbs(pad),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: CategoryFilterChips(
                        selected: _filter,
                        onChanged: (f) => setState(() => _filter = f),
                        padding: pad,
                      ),
                    ),
                    Expanded(child: _body(visible, grid, pad)),
                  ],
                ),
        );
      },
    );
  }

  PreferredSizeWidget _normalBar(bool grid) {
    return AppBar(
      leading: _atRoot
          ? null
          : IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Up', onPressed: _goBack),
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search in this folder',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            )
          : Text(
              _path == null
                  ? 'Browse'
                  : (_atRoot ? (_crumbs().firstOrNull?.$1 ?? 'Browse') : _scope.backend.nameOf(_path!)),
            ),
      actions: [
        IconButton(
          tooltip: _searching ? 'Close search' : 'Search',
          icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _query = '';
              _searchController.clear();
            }
          }),
        ),
        SortMenuButton(options: _sort, compact: true, onChanged: (s) => setState(() => _sort = s)),
        IconButton(
          tooltip: grid ? 'List view' : 'Grid view',
          icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          onPressed: () => _scope.settings.gridView = !grid,
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) {
            switch (v) {
              case 'folder':
                _newFolder();
              case 'import':
                _import();
              case 'refresh':
                if (_path != null) _load(_path!);
              case 'hidden':
                _scope.settings.showHidden = !_scope.settings.showHidden;
                if (_path != null) _load(_path!);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'folder',
              child: ListTile(leading: Icon(Icons.create_new_folder_outlined), title: Text('New folder')),
            ),
            if (_scope.backend.supportsImport)
              const PopupMenuItem(
                value: 'import',
                child: ListTile(leading: Icon(Icons.upload_file_rounded), title: Text('Import files')),
              ),
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Refresh')),
            ),
            CheckedPopupMenuItem(
              value: 'hidden',
              checked: _scope.settings.showHidden,
              child: const Text('Show hidden files'),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _selectionBar(List<FileEntry> visible) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected.toList();
    return AppBar(
      backgroundColor: scheme.secondaryContainer,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel',
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all_rounded),
          onPressed: () =>
              setState(() => _selected.length == visible.length ? _selected.clear() : _selected.addAll(visible)),
        ),
        IconButton(
          tooltip: 'Copy to',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await transferEntries(context, selected, move: false);
            if (mounted) setState(_selected.clear);
          },
        ),
        IconButton(
          tooltip: 'Move to',
          icon: const Icon(Icons.drive_file_move_outline),
          onPressed: () async {
            await transferEntries(context, selected, move: true);
            if (mounted) setState(_selected.clear);
          },
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            await deleteEntries(context, selected);
            if (mounted) setState(_selected.clear);
          },
        ),
        if (_selected.length == 1)
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              final e = _selected.first;
              setState(_selected.clear);
              showFileActions(context, e, siblings: visible);
            },
          ),
      ],
    );
  }

  Widget _breadcrumbs(EdgeInsets pad) {
    final crumbs = _crumbs();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: false,
        padding: pad,
        itemCount: crumbs.length,
        separatorBuilder: (_, _) => Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
        itemBuilder: (context, i) {
          final (name, path) = crumbs[i];
          final last = i == crumbs.length - 1;
          final avatar = i == 0 ? Icon(Icons.home_rounded, size: 18, color: scheme.primary) : null;
          return Center(
            child: last
                ? Chip(
                    avatar: avatar,
                    label: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    side: BorderSide.none,
                    backgroundColor: scheme.secondaryContainer,
                  )
                : ActionChip(
                    avatar: avatar,
                    label: Text(name),
                    side: BorderSide.none,
                    backgroundColor: scheme.surfaceContainerHigh,
                    onPressed: () => _load(path),
                  ),
          );
        },
      ),
    );
  }

  Widget _body(List<FileEntry> visible, bool grid, EdgeInsets pad) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open folder',
        message: _error,
        action: _atRoot ? null : OutlinedButton(onPressed: _goBack, child: const Text('Go back')),
      );
    }
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(_path!),
        child: ListView(
          children: [
            const SizedBox(height: 60),
            EmptyState(
              icon: _query.isNotEmpty || _filter.isNotEmpty ? Icons.search_off_rounded : Icons.folder_open_rounded,
              title: _query.isNotEmpty || _filter.isNotEmpty ? 'No matching files' : 'This folder is empty',
            ),
          ],
        ),
      );
    }
    final bottom = const EdgeInsets.only(bottom: 96);
    return RefreshIndicator(
      onRefresh: () => _load(_path!),
      child: ContentWidth(
        maxWidth: 1400,
        child: grid
            ? LayoutBuilder(
                builder: (context, c) => GridView.builder(
                  padding: pad.copyWith(top: 8) + bottom,
                  gridDelegate: fileGridDelegate(c.maxWidth),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    return FileGridTile(
                      entry: e,
                      selected: _selected.contains(e),
                      onTap: () => _tap(e, visible),
                      onLongPress: () => _longPress(e),
                      onMore: _selectionMode ? null : () => showFileActions(context, e, siblings: visible),
                    );
                  },
                ),
              )
            : ListView.builder(
                padding: pad + bottom,
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final e = visible[i];
                  return FileListTile(
                    entry: e,
                    selected: _selected.contains(e),
                    selectionMode: _selectionMode,
                    onTap: () => _tap(e, visible),
                    onLongPress: () => _longPress(e),
                    onMore: () => showFileActions(context, e, siblings: visible),
                  );
                },
              ),
      ),
    );
  }
}
