import 'dart:typed_data';

import 'external_opener_stub.dart'
    if (dart.library.io) 'external_opener_io.dart'
    if (dart.library.js_interop) 'external_opener_web.dart'
    as impl;

enum OpenOutcome { opened, noAppFound, permissionDenied, error }

class OpenResultInfo {
  const OpenResultInfo(this.outcome, [this.message = '']);
  final OpenOutcome outcome;
  final String message;
  bool get ok => outcome == OpenOutcome.opened;
}

/// Hands a file to another app (mobile) or to the browser (web).
class ExternalOpener {
  const ExternalOpener._();

  /// Opens [path] with the best matching app. On the web [bytes] are required
  /// and the file opens in a new tab (or downloads when the browser can't show it).
  static Future<OpenResultInfo> open({required String path, required String name, Uint8List? bytes}) =>
      impl.openExternally(path: path, name: name, bytes: bytes);

  /// Saves a copy through the browser's download (web only).
  static Future<void> download({required String name, required Uint8List bytes}) =>
      impl.downloadBytes(name: name, bytes: bytes);

  /// Starts the Android package installer for an APK.
  static Future<OpenResultInfo> installApk(String path) => impl.installApk(path);
}
