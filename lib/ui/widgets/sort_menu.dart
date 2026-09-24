import 'package:flutter/material.dart';

import '../../core/file_category.dart';
import '../../core/sorting.dart';

/// "Sort" button with a popup of fields and a direction toggle.
class SortMenuButton extends StatelessWidget {
  const SortMenuButton({super.key, required this.options, required this.onChanged, this.compact = false});

  final SortOptions options;
  final ValueChanged<SortOptions> onChanged;
  final bool compact;

  String get _directionLabel => switch (options.field) {
    SortField.name || SortField.type => options.ascending ? 'A → Z' : 'Z → A',
    SortField.date => options.ascending ? 'Oldest first' : 'Newest first',
    SortField.size => options.ascending ? 'Smallest first' : 'Largest first',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Sort',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value is SortField) {
          onChanged(
            value == options.field ? options.copyWith(ascending: !options.ascending) : SortOptions.defaultFor(value),
          );
        } else if (value == #toggle) {
          onChanged(options.copyWith(ascending: !options.ascending));
        }
      },
      itemBuilder: (context) => [
        for (final f in SortField.values)
          CheckedPopupMenuItem<Object>(value: f, checked: f == options.field, child: Text(f.label)),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: #toggle,
          child: Row(
            children: [
              Icon(options.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 20),
              const SizedBox(width: 12),
              Text(_directionLabel),
            ],
          ),
        ),
      ],
      child: compact
          ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.sort_rounded))
          : Chip(
              avatar: Icon(options.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 18),
              label: Text('${options.field.label} · $_directionLabel'),
            ),
    );
  }
}

/// Horizontally scrolling category filter chips ("All", "Images", ...).
class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final Set<FileCategory> selected;
  final ValueChanged<Set<FileCategory>> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          FilterChip(label: const Text('All'), selected: selected.isEmpty, onSelected: (_) => onChanged({})),
          for (final c in FileCategory.values)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                avatar: selected.contains(c) ? null : Icon(c.icon, size: 18, color: c.color),
                label: Text(c.label),
                selected: selected.contains(c),
                onSelected: (on) {
                  final next = Set.of(selected);
                  on ? next.add(c) : next.remove(c);
                  onChanged(next);
                },
              ),
            ),
        ],
      ),
    );
  }
}
