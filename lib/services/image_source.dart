import 'package:flutter/widgets.dart';

import '../core/file_entry.dart';
import 'image_source_stub.dart' if (dart.library.io) 'image_source_io.dart' as impl;
import 'storage/storage_backend.dart';

/// Returns an image provider for [entry], reading from disk on mobile and
/// from memory on the web.
Future<ImageProvider> imageProviderFor(StorageBackend backend, FileEntry entry) async {
  if (backend.isDeviceStorage) {
    final provider = impl.fileImage(entry.path);
    if (provider != null) return provider;
  }
  return MemoryImage(await backend.readBytes(entry.path));
}
