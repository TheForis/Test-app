import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../core/format.dart';
import '../../core/sorting.dart';
import '../../services/storage/storage_backend.dart';
import '../../state/app_scope.dart';
import '../../state/file_index.dart';
import '../../state/storage_breakdown.dart';
import '../burrow/burrow_screen.dart';
import '../category/category_screen.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_thumb.dart';
import '../widgets/file_tile.dart';
import '../widgets/scan_feedback.dart';
import '../widgets/storage_tube.dart';

enum RecentOrder {
  newest('Newest'),
  oldest('Oldest'),
  largest('Largest');

  const RecentOrder(this.label);
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RecentOrder _order = RecentOrder.newest;
  Set<FileCategory> _recentFilter = {};
  int _recentLimit = 20;

  static const _homeCategories = [
    FileCategory.image,
    FileCategory.video,
    FileCategory.audio,
    FileCategory.document,
    FileCategory.apk,
    FileCategory.archive,
  ];

  Future<void> _refresh() async {
    // Locations are loaded at startup; re-read them in case an SD card appeared.
    await AppScope.of(context).index.reloadLocations();
    if (mounted) await refreshWithReport(context);
  }

  List<FileEntry> _recentFiles(List<FileEntry> files) {
    var list = filterEntries(files, categories: _recentFilter);
    final SortOptions sort = switch (_order) {
      RecentOrder.newest => const SortOptions(field: SortField.date, ascending: false),
      RecentOrder.oldest => const SortOptions(field: SortField.date, ascending: true),
      RecentOrder.largest => const SortOptions(field: SortField.size, ascending: false),
    };
    list = sortEntries(list, sort);
    return list.take(_recentLimit).toList();
  }

  Future<void> _import() async {
    final scope = AppScope.of(context);
    final root = await scope.backend.rootPath();
    final target = scope.backend.isDeviceStorage ? root : scope.backend.join(root, 'Downloads');
    if (!mounted) return;
    final count = await runFileOp(context, () => scope.backend.importFiles(target));
    if (count != null && count > 0 && mounted) {
      showMessage(context, 'Imported $count file${count == 1 ? '' : 's'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final index = scope.index;
    return ListenableBuilder(
      listenable: index,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final pad = pagePadding(context);
        final recent = _recentFiles(index.files);
        final recentAsGrid = width >= 900;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            edgeOffset: 100,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 72,
                  // The navigation rail already shows the logo on wider screens.
                  title: width < Breakpoints.compact
                      ? const BrandWordmark(logoSize: 36)
                      : Text(
                          'Home',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                  actions: [
                    if (scope.backend.supportsImport)
                      IconButton(
                        tooltip: 'Import files',
                        icon: const Icon(Icons.upload_file_rounded),
                        onPressed: _import,
                      ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: index.loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : const Icon(Icons.refresh_rounded),
                      onPressed: index.loading ? null : _refresh,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: pad,
                      child: _SearchLauncher(onTap: () => ShellScope.of(context).tab = 2),
                    ),
                  ),
                ),
                if (!index.hasAccess)
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: Padding(padding: pad.copyWith(top: 20), child: const _PermissionCard()),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: Padding(padding: pad.copyWith(top: 20), child: const _BurrowHero()),
                    ),
                  ),
                  _sectionHeader(context, 'Storage'),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: _StorageStrip(locations: index.locations, padding: pad),
                    ),
                  ),
                  _sectionHeader(context, 'Categories'),
                  SliverPadding(
                    padding: pad,
                    sliver: SliverToBoxAdapter(
                      child: ContentWidth(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final columns = c.maxWidth >= 1000 ? 6 : (c.maxWidth >= 640 ? 3 : 2);
                            return GridView(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: columns == 6 ? 160 : 136,
                              ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final cat in _homeCategories)
                                  CategoryCard(
                                    category: cat,
                                    count: index.statsFor(cat).count,
                                    bytes: index.statsFor(cat).bytes,
                                    loading: index.loading && !index.loadedOnce,
                                    onTap: () =>
                                        Navigator.of(context)
                                            .push(MaterialPageRoute(builder: (_) => CategoryScreen(category: cat))),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: Padding(
                        padding: pad.copyWith(top: 28, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent files',
                                    style: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (index.lastScan != null)
                                    Text(
                                      'Updated ${formatDate(index.lastScan!).toLowerCase()}',
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Refresh recent files',
                              onPressed: index.loading ? null : _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: pad,
                        child: Row(
                          children: [
                            SegmentedButton<RecentOrder>(
                              showSelectedIcon: false,
                              segments: [
                                for (final o in RecentOrder.values) ButtonSegment(value: o, label: Text(o.label)),
                              ],
                              selected: {_order},
                              onSelectionChanged: (s) => setState(() => _order = s.first),
                            ),
                            const SizedBox(width: 12),
                            for (final c in _homeCategories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(c.label),
                                  avatar: _recentFilter.contains(c) ? null : Icon(c.icon, size: 18, color: c.color),
                                  selected: _recentFilter.contains(c),
                                  onSelected: (on) => setState(() {
                                    _recentFilter = on ? {c} : {};
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (index.loading && !index.loadedOnce)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (index.error != null)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Something went wrong',
                        message: index.error,
                      ),
                    )
                  else if (recent.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No recent files',
                        message: scope.backend.supportsImport
                            ? 'Import files to get started.'
                            : 'Files you add will show up here.',
                        action: scope.backend.supportsImport
                            ? FilledButton.icon(
                                onPressed: _import,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Import files'),
                              )
                            : null,
                      ),
                    )
                  else if (recentAsGrid)
                    SliverPadding(
                      padding: pad,
                      sliver: SliverToBoxAdapter(
                        child: ContentWidth(
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              mainAxisExtent: 76,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: recent.length,
                            itemBuilder: (context, i) => _recentTile(context, recent[i], recent),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: pad,
                      sliver: SliverList.builder(
                        itemCount: recent.length,
                        itemBuilder: (context, i) => _recentTile(context, recent[i], recent),
                      ),
                    ),
                  if (recent.length >= _recentLimit && index.files.length > _recentLimit)
                    SliverToBoxAdapter(
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _recentLimit += 20),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Show more'),
                        ),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recentTile(BuildContext context, FileEntry e, List<FileEntry> all) => FileListTile(
    entry: e,
    subtitle: '${formatBytes(e.size)} • ${formatDate(e.modified)}',
    onTap: () => openEntry(context, e, siblings: all),
    onLongPress: () => showFileActions(context, e, siblings: all),
    onMore: () => showFileActions(context, e, siblings: all),
  );

  Widget _sectionHeader(BuildContext context, String title) => SliverToBoxAdapter(
    child: ContentWidth(
      child: Padding(
        padding: pagePadding(context).copyWith(top: 28, bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

/// Signature card: device capacity as a glass tube filled with a band per
/// kind of file. Tap it to explore the burrow.
class _BurrowHero extends StatelessWidget {
  const _BurrowHero();

  // AppScope.of doesn't subscribe to changes, and this widget is const, so it
  // must listen to the index itself or it keeps showing its first state.
  @override
  Widget build(BuildContext context) {
    final index = AppScope.of(context).index;
    return ListenableBuilder(listenable: index, builder: (context, _) => _build(context, index));
  }

  Widget _build(BuildContext context, FileIndex index) {
    final text = Theme.of(context).textTheme;
    final scanning = index.loading && !index.loadedOnce;
    final b = StorageBreakdown.of(index);
    final segments = [for (final p in b.parts) TubeSegment(label: p.label, bytes: p.bytes, color: p.color)];
    final white70 = Colors.white.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.inkLight, Brand.ink],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Brand.ink.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Oversized mark as a watermark.
          const Positioned(
            right: -36,
            top: -28,
            child: CustomPaint(
              size: Size.square(180),
              painter: BurrowMarkPainter(background: false, monochrome: Color(0x14FFFFFF)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Your burrow',
                      style: text.titleSmall?.copyWith(color: Brand.glow, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    // The saved index is already on screen; this is the quiet background check.
                    if (index.loading && index.loadedOnce)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: CheckingIndicator(color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: scanning ? 'Digging…' : formatBytes(b.used)),
                      if (!scanning && b.free != null)
                        TextSpan(
                          text: '  of ${formatCapacity(b.capacity)}',
                          style: text.titleMedium?.copyWith(color: white70, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  style: text.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  scanning
                      ? 'Indexing your files'
                      : [
                          if (b.free != null) '${formatBytes(b.free!)} free',
                          '${formatCount(index.files.length)} file${index.files.length == 1 ? '' : 's'} indexed',
                        ].join(' · '),
                  style: text.bodyMedium?.copyWith(color: white70),
                ),
                const SizedBox(height: 18),
                if (scanning || b.capacity == 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: LinearProgressIndicator(
                      minHeight: 30,
                      value: scanning ? null : 0,
                      color: Brand.ember,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  )
                else
                  StorageTube(segments: segments, capacity: b.capacity),
                if (!scanning && b.parts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final columns = c.maxWidth >= 720 ? 5 : (c.maxWidth >= 440 ? 4 : 3);
                      final width = (c.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final p in b.parts) _legend(context, width, p.color, p.label, p.bytes),
                          if (b.free != null) _legend(context, width, null, 'Free', b.free!),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Explore your burrow',
                        style: text.labelLarge?.copyWith(color: Brand.glow, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Brand.glow),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: scanning
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BurrowScreen())),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Name over size, so nothing is cut off on narrow phones.
  Widget _legend(BuildContext context, double width, Color? color, String label, int bytes) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color == null ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5) : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              formatBytes(bytes),
              style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text('Search all files', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern gradient card for a file category.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.count,
    required this.bytes,
    required this.onTap,
    this.loading = false,
  });

  final FileCategory category;
  final int count;
  final int bytes;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: category.linearGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: category.color.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(category.icon, size: 96, color: Colors.white.withValues(alpha: 0.16)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(category.icon, color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading ? 'Scanning…' : '$count file${count == 1 ? '' : 's'} • ${formatBytes(bytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageStrip extends StatelessWidget {
  const _StorageStrip({required this.locations, required this.padding});
  final List<StorageLocation> locations;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final index = scope.index;
    final scheme = Theme.of(context).colorScheme;
    if (locations.isEmpty) return const SizedBox(height: 120);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final loc = locations[i];
          final primary = i == 0;
          final fg = primary ? scheme.onPrimary : scheme.onSurface;
          return SizedBox(
            width: primary ? 240 : 160,
            child: Card(
              color: primary ? scheme.primary : scheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ShellScope.of(context).openFolder(loc.path),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(loc.icon, color: primary ? scheme.onPrimary : scheme.primary),
                      const Spacer(),
                      Text(
                        loc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        primary ? '${index.files.length} files • ${formatBytes(index.totalBytes)}' : 'Open folder',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                      if (primary) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: index.loading ? null : 1,
                            minHeight: 6,
                            color: scheme.onPrimary,
                            backgroundColor: scheme.onPrimary.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppScope.of(context).index, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final permanently = scope.index.access == AccessState.permanentlyDenied;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.folder_special_rounded, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              'Allow access to your files',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${Brand.name} needs "All files access" to browse, search, open, unzip and install files on your device.',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => permanently
                  ? scope.backend.openAccessSettings()
                  : scope.index.requestAccess(showHidden: scope.settings.showHidden),
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(permanently ? 'Open settings' : 'Grant access'),
            ),
          ],
        ),
      ),
    );
  }
}
