import 'package:flutter/material.dart';

import '../core/file_category.dart';
import 'file_index.dart';

/// One kind of data taking up space: a file category, or everything Burrow
/// can't see (the OS, installed apps and their private data).
class BreakdownPart {
  const BreakdownPart({
    required this.label,
    required this.bytes,
    required this.color,
    required this.icon,
    this.category,
    this.count,
  });

  final String label;
  final int bytes;
  final Color color;
  final IconData icon;

  /// Null for "System & apps".
  final FileCategory? category;
  final int? count;
}

/// What fills the device, largest first. Shared by the home card and the
/// burrow screen so they always agree.
class StorageBreakdown {
  const StorageBreakdown({required this.parts, required this.capacity, required this.used, required this.free});

  factory StorageBreakdown.of(FileIndex index) {
    final space = index.space;
    final indexed = index.totalBytes;
    final parts = [
      for (final c in FileCategory.values)
        if (index.statsFor(c).bytes > 0)
          BreakdownPart(
            label: c == FileCategory.apk ? 'Apps' : c.label,
            bytes: index.statsFor(c).bytes,
            color: c.color,
            icon: c.icon,
            category: c,
            count: index.statsFor(c).count,
          ),
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));
    final capacity = space?.advertised ?? indexed;
    final used = space == null ? indexed : capacity - space.free;
    final system = space == null ? 0 : (used - indexed).clamp(0, capacity);
    if (system > 0) {
      parts.add(BreakdownPart(label: 'System & apps', bytes: system, color: systemColor, icon: Icons.memory_rounded));
    }
    return StorageBreakdown(parts: parts, capacity: capacity, used: used, free: space?.free);
  }

  static const systemColor = Color(0xFF8A84A3);

  final List<BreakdownPart> parts;

  /// Marketed device size on phones; total indexed bytes on the web.
  final int capacity;
  final int used;

  /// Null where the device size is unknown (web).
  final int? free;

  double shareOf(int bytes) => capacity <= 0 ? 0 : bytes / capacity;
}
