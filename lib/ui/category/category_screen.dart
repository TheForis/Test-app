import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/format.dart';
import '../../core/sorting.dart';
import '../../state/app_scope.dart';
import '../theme.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_thumb.dart';
import '../widgets/file_tile.dart';
import '../widgets/sort_menu.dart';

/// All files of one category (e.g. every PDF, every APK) across storage.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.category});

  final FileCategory category;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  SortOptions _sort = const SortOptions(field: SortField.date, ascending: false);
  String _query = '';
  String? _extension;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final cat = widget.category;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.index, scope.settings]),
      builder: (context, _) {
        final all = scope.index.byCategory(cat);
        final extensions = (all.map((e) => e.extension).where((e) => e.isNotEmpty).toSet().toList()..sort());
        var files = filterEntries(all, query: _query);
        if (_extension != null) files = files.where((f) => f.extension == _extension).toList();
        files = sortEntries(files, _sort);
        final stats = scope.index.statsFor(cat);
        final grid = scope.settings.gridView;
        final pad = pagePadding(context);
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => scope.index.refresh(showHidden: scope.settings.showHidden),
            edgeOffset: 160,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 170,
                  foregroundColor: Colors.white,
                  backgroundColor: cat.color,
                  actions: [
                    SortMenuButton(options: _sort, compact: true, onChanged: (s) => setState(() => _sort = s)),
                    IconButton(
                      tooltip: grid ? 'List view' : 'Grid view',
                      icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                      onPressed: () => scope.settings.gridView = !grid,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      cat.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    background: DecoratedBox(
                      decoration: BoxDecoration(gradient: cat.linearGradient),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -30,
                            child: Icon(cat.icon, size: 180, color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: pad.copyWith(top: 16, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats.count} file${stats.count == 1 ? '' : 's'} • ${formatBytes(stats.bytes)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search ${cat.label.toLowerCase()}',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (extensions.length > 1)
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: pad.copyWith(bottom: 8),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All types'),
                            selected: _extension == null,
                            onSelected: (_) => setState(() => _extension = null),
                          ),
                          for (final ext in extensions)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(ext.toUpperCase()),
                                selected: _extension == ext,
                                onSelected: (on) => setState(() => _extension = on ? ext : null),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (scope.index.loading && !scope.index.loadedOnce)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (files.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: cat.icon,
                      title: _query.isEmpty ? 'No ${cat.label.toLowerCase()} found' : 'No matching files',
                    ),
                  )
                else if (grid)
                  SliverPadding(
                    padding: pad.copyWith(top: 8, bottom: 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, c) => SliverGrid.builder(
                        gridDelegate: fileGridDelegate(c.crossAxisExtent),
                        itemCount: files.length,
                        itemBuilder: (context, i) => FileGridTile(
                          entry: files[i],
                          onTap: () => openEntry(context, files[i], siblings: files),
                          onLongPress: () => showFileActions(context, files[i], siblings: files),
                          onMore: () => showFileActions(context, files[i], siblings: files),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: pad.copyWith(bottom: 32),
                    sliver: SliverList.builder(
                      itemCount: files.length,
                      itemBuilder: (context, i) => ContentWidth(
                        child: FileListTile(
                          entry: files[i],
                          onTap: () => openEntry(context, files[i], siblings: files),
                          onLongPress: () => showFileActions(context, files[i], siblings: files),
                          onMore: () => showFileActions(context, files[i], siblings: files),
                        ),
                      ),
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
