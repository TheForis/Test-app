import 'dart:typed_data';

import 'external_opener.dart';

Future<OpenResultInfo> openExternally({required String path, required String name, Uint8List? bytes}) async =>
    const OpenResultInfo(OpenOutcome.error, 'Opening files is not supported on this platform');

Future<void> downloadBytes({required String name, required Uint8List bytes}) async {}

Future<OpenResultInfo> installApk(String path) async =>
    const OpenResultInfo(OpenOutcome.error, 'APK files can only be installed on Android');
