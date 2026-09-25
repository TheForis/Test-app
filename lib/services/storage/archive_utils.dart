import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Decodes zip / tar / tar.gz / tar.bz2 / tar.xz archives held in memory.
/// Single-file compressed streams (.gz, .bz2, .xz) become a one-entry archive.
Archive decodeArchiveBytes(String fileName, Uint8List bytes) {
  final n = fileName.toLowerCase();
  if (n.endsWith('.zip') || n.endsWith('.jar') || n.endsWith('.apk')) {
    return ZipDecoder().decodeBytes(bytes);
  }
  if (n.endsWith('.tar')) return TarDecoder().decodeBytes(bytes);
  if (n.endsWith('.tar.gz') || n.endsWith('.tgz')) {
    return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  }
  if (n.endsWith('.tar.bz2') || n.endsWith('.tbz2')) {
    return TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
  }
  if (n.endsWith('.tar.xz') || n.endsWith('.txz')) {
    return TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
  }
  Uint8List? single;
  String? inner;
  if (n.endsWith('.gz')) {
    single = GZipDecoder().decodeBytes(bytes);
    inner = fileName.substring(0, fileName.length - 3);
  } else if (n.endsWith('.bz2')) {
    single = BZip2Decoder().decodeBytes(bytes);
    inner = fileName.substring(0, fileName.length - 4);
  } else if (n.endsWith('.xz')) {
    single = XZDecoder().decodeBytes(bytes);
    inner = fileName.substring(0, fileName.length - 3);
  }
  if (single != null && inner != null) {
    final archive = Archive();
    archive.add(ArchiveFile.bytes(inner, single));
    return archive;
  }
  throw const FormatException('Unsupported archive format');
}

/// Normalises an archive entry name and rejects entries that would escape the
/// extraction folder ("zip slip").
String? safeArchivePath(String name) {
  final parts = <String>[];
  for (final part in name.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') return null;
    parts.add(part);
  }
  if (parts.isEmpty) return null;
  return parts.join('/');
}

/// Strips archive extensions: "photos.tar.gz" -> "photos".
String archiveBaseName(String fileName) {
  final lower = fileName.toLowerCase();
  for (final ext in [
    '.tar.gz',
    '.tar.bz2',
    '.tar.xz',
    '.tgz',
    '.tbz2',
    '.txz',
    '.zip',
    '.jar',
    '.tar',
    '.gz',
    '.bz2',
    '.xz',
  ]) {
    if (lower.endsWith(ext) && fileName.length > ext.length) {
      return fileName.substring(0, fileName.length - ext.length);
    }
  }
  return fileName;
}
