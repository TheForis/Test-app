import 'dart:typed_data';

import 'package:video_player/video_player.dart';

import 'media_source.dart';

MediaHandle? fromFile(String path, VideoPlayerOptions options) => null;

MediaHandle fromBytes(String name, Uint8List bytes, VideoPlayerOptions options) =>
    throw UnsupportedError('Media playback is not available on this platform');
