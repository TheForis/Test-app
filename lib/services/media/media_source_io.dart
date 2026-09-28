import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import 'media_source.dart';

MediaHandle? fromFile(String path, VideoPlayerOptions options) =>
    MediaHandle(VideoPlayerController.file(File(path), videoPlayerOptions: options));

/// In-memory files (only used off-device) play from a temporary copy that is
/// deleted when the player closes.
MediaHandle fromBytes(String name, Uint8List bytes, VideoPlayerOptions options) {
  final dir = Directory.systemTemp.createTempSync('burrow_media');
  final file = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
  return MediaHandle(
    VideoPlayerController.file(file, videoPlayerOptions: options),
    onRelease: () {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    },
  );
}
