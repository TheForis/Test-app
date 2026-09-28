import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/format.dart';
import '../../state/app_scope.dart';
import '../../state/file_index.dart';
import '../../state/storage_breakdown.dart';
import '../category/category_screen.dart';
import '../theme.dart';
import '../widgets/scan_feedback.dart';
import 'burrow_map.dart';

/// "Your burrow": where your storage goes, drawn as chambers underground.
class BurrowScreen extends StatelessWidget {
  const BurrowScreen({super.key});

  void _open(BuildContext context, BreakdownPart part) {
    final category = part.category;
    if (category == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: category)));
  }

  @override
  Widget build(BuildContext context) {
    final index = AppScope.of(context).index;
    return ListenableBuilder(
      listenable: index,
      builder: (context, _) {
        final b = StorageBreakdown.of(index);
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        final pad = pagePadding(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Your burrow', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ContentWidth(
            maxWidth: 760,
            child: ListView(
              padding: pad.copyWith(bottom: 32),
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: formatBytes(b.used)),
                      if (b.free != null)
                        TextSpan(
                          text: '  of ${formatCapacity(b.capacity)} used',
                          style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (b.free != null) '${formatBytes(b.free!)} free',
                    '${formatCount(index.files.length)} files in ${b.parts.length} chambers',
                  ].join(' · '),
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                const _IndexStatus(),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Brand.inkLight, Brand.ink],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: b.parts.isEmpty
                      ? const SizedBox(
                          height: 220,
                          child: Center(
                            child: Text('Your burrow is empty', style: TextStyle(color: Colors.white70)),
                          ),
                        )
                      : BurrowMap(breakdown: b, onTap: (p) => _open(context, p)),
                ),
                const SizedBox(height: 24),
                Text('Chambers', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final p in b.parts) _row(context, b, p),
                      if (b.free != null)
                        ListTile(
                          leading: _badge(Brand.glow, Icons.check_circle_outline_rounded),
                          title: const Text('Free space'),
                          subtitle: const Text('Room to dig'),
                          trailing: Text(formatBytes(b.free!), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
                if (b.free == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'In the browser Burrow only sees files you import, so device capacity isn\'t shown.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, StorageBreakdown b, BreakdownPart p) {
    final scheme = Theme.of(context).colorScheme;
    final share = b.shareOf(p.bytes);
    return ListTile(
      leading: _badge(p.color, p.icon),
      title: Text(p.label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.01, 1.0),
            minHeight: 6,
            color: p.color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatBytes(p.bytes), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            p.count == null ? 'Not browsable' : '${p.count} files',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      onTap: p.category == null ? null : () => _open(context, p),
    );
  }

  Widget _badge(Color color, IconData icon) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: color, size: 22),
  );
}

/// When the index was last checked, what changed, and a Refresh button. A
/// refresh only re-reads folders that changed since the last check.
class _IndexStatus extends StatelessWidget {
  const _IndexStatus();

  // Const and read through AppScope, so it must listen to the index itself.
  @override
  Widget build(BuildContext context) {
    final index = AppScope.of(context).index;
    return ListenableBuilder(listenable: index, builder: (context, _) => _build(context, index));
  }

  Widget _build(BuildContext context, FileIndex index) {
    final scheme = Theme.of(context).colorScheme;
    final report = index.lastReport;
    final loading = index.loading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.primary),
                    )
                  : Icon(
                      report == null || !report.hasChanges ? Icons.task_alt_rounded : Icons.update_rounded,
                      color: scheme.primary,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loading ? 'Checking for changes…' : (report == null ? 'Index loaded' : describeScan(report)),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (index.lastScan != null) 'Last checked ${formatDate(index.lastScan!).toLowerCase()}',
                      if (report == null || !report.firstScan) '${formatCount(index.files.length)} files indexed',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: loading ? null : () => refreshWithReport(context),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
