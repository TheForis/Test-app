import 'dart:js_interop';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'media_source.dart';

MediaHandle? fromFile(String path, VideoPlayerOptions options) => null;

/// Plays imported files through a blob URL, revoked when the player closes.
MediaHandle fromBytes(String name, Uint8List bytes, VideoPlayerOptions options) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  return MediaHandle(
    VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: options),
    onRelease: () => web.URL.revokeObjectURL(url),
  );
}
