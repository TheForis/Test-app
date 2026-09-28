import 'package:video_player/video_player.dart';

import '../../core/file_entry.dart';
import '../storage/storage_backend.dart';
import 'media_source_stub.dart'
    if (dart.library.io) 'media_source_io.dart'
    if (dart.library.js_interop) 'media_source_web.dart'
    as impl;

/// A player for one file, plus whatever must be released with it.
class MediaHandle {
  MediaHandle(this.controller, {this.onRelease});

  final VideoPlayerController controller;

  /// Frees what backs the player (a temporary file or a browser blob URL).
  final void Function()? onRelease;

  Future<void> dispose() async {
    await controller.dispose();
    onRelease?.call();
  }
}

/// Opens [entry] for playback: straight from disk on phones, from a
/// temporary in-memory URL in the browser.
Future<MediaHandle> openMedia(StorageBackend backend, FileEntry entry, {bool keepPlayingInBackground = false}) async {
  final options = VideoPlayerOptions(allowBackgroundPlayback: keepPlayingInBackground);
  if (backend.isDeviceStorage) {
    final handle = impl.fromFile(entry.path, options);
    if (handle != null) return handle;
  }
  return impl.fromBytes(entry.name, await backend.readBytes(entry.path), options);
}
