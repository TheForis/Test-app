import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/app_scope.dart';
import '../../state/file_index.dart';
import 'file_actions.dart';

/// One-line summary of a scan: "Up to date · no changes (0.4 s)".
String describeScan(ScanReport report) {
  final time = _seconds(report.elapsed);
  if (report.firstScan) return 'Indexed ${formatCount(report.total)} files ($time)';
  if (!report.hasChanges) return 'Up to date · no changes ($time)';
  final parts = [
    if (report.added > 0) '${formatCount(report.added)} new',
    if (report.removed > 0) '${formatCount(report.removed)} removed',
    if (report.changed > 0) '${formatCount(report.changed)} changed',
  ];
  return 'Updated · ${parts.join(' · ')} ($time)';
}

String _seconds(Duration d) {
  final s = d.inMilliseconds / 1000;
  return s < 10 ? '${s.toStringAsFixed(1)} s' : '${s.round()} s';
}

/// Refreshes the index (only changed folders, unless [full]) and tells the
/// user what changed.
Future<void> refreshWithReport(BuildContext context, {bool full = false}) async {
  final scope = AppScope.of(context);
  if (scope.index.loading) {
    showMessage(context, 'Already checking for changes…');
    return;
  }
  final report = await scope.index.refresh(showHidden: scope.settings.showHidden, full: full);
  if (!context.mounted) return;
  if (report != null) {
    showMessage(context, describeScan(report));
  } else if (scope.index.error != null) {
    showMessage(context, scope.index.error!);
  }
}

/// Small spinner with a label, for background checks.
class CheckingIndicator extends StatelessWidget {
  const CheckingIndicator({super.key, required this.color, this.label = 'Checking for changes…'});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}
