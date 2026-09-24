import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import 'external_opener.dart';

Future<OpenResultInfo> openExternally({required String path, required String name, Uint8List? bytes}) async {
  try {
    final result = await OpenFilex.open(path, type: lookupMimeType(name));
    return switch (result.type) {
      ResultType.done => const OpenResultInfo(OpenOutcome.opened),
      ResultType.noAppToOpen => const OpenResultInfo(OpenOutcome.noAppFound, 'No app found to open this file'),
      ResultType.permissionDenied => OpenResultInfo(OpenOutcome.permissionDenied, result.message),
      _ => OpenResultInfo(OpenOutcome.error, result.message),
    };
  } catch (e) {
    return OpenResultInfo(OpenOutcome.error, '$e');
  }
}

Future<void> downloadBytes({required String name, required Uint8List bytes}) async {}

Future<OpenResultInfo> installApk(String path) async {
  if (!Platform.isAndroid) {
    return const OpenResultInfo(OpenOutcome.error, 'APK files can only be installed on Android');
  }
  // Android 8+ asks the user once to allow installs from this app.
  var status = await Permission.requestInstallPackages.status;
  if (!status.isGranted) status = await Permission.requestInstallPackages.request();
  if (!status.isGranted) {
    return const OpenResultInfo(
      OpenOutcome.permissionDenied,
      'Allow "Install unknown apps" for File Manager to install APKs',
    );
  }
  try {
    final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
    return result.type == ResultType.done
        ? const OpenResultInfo(OpenOutcome.opened)
        : OpenResultInfo(OpenOutcome.error, result.message);
  } catch (e) {
    return OpenResultInfo(OpenOutcome.error, '$e');
  }
}
