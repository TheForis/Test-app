import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

String _locale = 'en_US';

/// Loads date symbols for the device locale, falling back to en_US for
/// locales intl doesn't know (some browsers report tags like "en-US-u-...").
Future<void> initDateFormatting(String? deviceLocale) async {
  await initializeDateFormatting();
  if (deviceLocale == null) return;
  try {
    final canonical = Intl.canonicalizedLocale(deviceLocale.replaceAll('-', '_'));
    final verified = Intl.verifiedLocale(canonical, DateFormat.localeExists, onFailure: (_) => null);
    if (verified != null) _locale = verified;
  } catch (_) {}
}

/// Human-readable size in decimal units (1 KB = 1000 bytes), matching how
/// Android and iOS report storage.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

/// "1,911" in the device's locale.
String formatCount(int n) => NumberFormat.decimalPattern(_locale).format(n);

/// Marketed capacity in decimal units, as printed on the box: "128 GB".
String formatCapacity(int bytes) {
  const gb = 1000 * 1000 * 1000;
  if (bytes >= 1000 * gb) return '${(bytes / (1000 * gb)).toStringAsFixed(bytes % (1000 * gb) == 0 ? 0 : 1)} TB';
  if (bytes >= gb) return '${(bytes / gb).round()} GB';
  return formatBytes(bytes);
}

String formatDate(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(date);
  if (diff.inSeconds < 60 && !diff.isNegative) return 'Just now';
  if (diff.inMinutes < 60 && !diff.isNegative) return '${diff.inMinutes} min ago';
  final sameDay = current.year == date.year && current.month == date.month && current.day == date.day;
  if (sameDay) return 'Today, ${DateFormat.jm(_locale).format(date)}';
  final yesterday = current.subtract(const Duration(days: 1));
  if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
    return 'Yesterday, ${DateFormat.jm(_locale).format(date)}';
  }
  if (current.year == date.year) return DateFormat.MMMd(_locale).add_jm().format(date);
  return DateFormat.yMMMd(_locale).format(date);
}

String formatFullDate(DateTime date) => DateFormat.yMMMMd(_locale).add_jms().format(date);
