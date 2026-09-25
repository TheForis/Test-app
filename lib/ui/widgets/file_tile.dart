import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../core/format.dart';
import 'file_thumb.dart';

String entrySubtitle(FileEntry e) => e.isDirectory
    ? '${e.size} item${e.size == 1 ? '' : 's'} • ${formatDate(e.modified)}'
    : '${formatBytes(e.size)} • ${formatDate(e.modified)}';

class FileListTile extends StatelessWidget {
  const FileListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
    this.selectionMode = false,
    this.subtitle,
  });

  final FileEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final bool selected;
  final bool selectionMode;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            FileThumb(entry: entry, size: 46),
            if (selected)
              Positioned(
                right: -4,
                bottom: -4,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary),
                ),
              ),
          ],
        ),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle ?? entrySubtitle(entry), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : (onMore == null
                  ? null
                  : IconButton(icon: const Icon(Icons.more_vert_rounded), tooltip: 'More', onPressed: onMore)),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class FileGridTile extends StatelessWidget {
  const FileGridTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
  });

  final FileEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Center(
                        child: FileThumb(entry: entry, size: c.biggest.shortestSide, radius: 16),
                      ),
                      if (selected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: scheme.primary,
                            child: Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                        Text(
                          entry.isDirectory ? '${entry.size} items' : formatBytes(entry.size),
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (onMore != null)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: onMore,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid delegate that fits as many ~170px columns as the width allows.
SliverGridDelegate fileGridDelegate(double width) => SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: width < 400 ? 170 : 190,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.82,
);

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
