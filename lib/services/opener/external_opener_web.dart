import 'dart:js_interop';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:web/web.dart' as web;

import 'external_opener.dart';

web.Blob _blob(String name, Uint8List bytes) => web.Blob(
  [bytes.toJS].toJS,
  web.BlobPropertyBag(type: lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream'),
);

Future<OpenResultInfo> openExternally({required String path, required String name, Uint8List? bytes}) async {
  if (bytes == null) return const OpenResultInfo(OpenOutcome.error, 'File content unavailable');
  final url = web.URL.createObjectURL(_blob(name, bytes));
  final opened = web.window.open(url, '_blank');
  if (opened == null) {
    // Pop-up blocked: fall back to a download.
    _clickDownload(url, name);
  }
  Future.delayed(const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));
  return const OpenResultInfo(OpenOutcome.opened);
}

void _clickDownload(String url, String name) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<void> downloadBytes({required String name, required Uint8List bytes}) async {
  final url = web.URL.createObjectURL(_blob(name, bytes));
  _clickDownload(url, name);
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

Future<OpenResultInfo> installApk(String path) async =>
    const OpenResultInfo(OpenOutcome.error, 'APK files can only be installed on an Android device');
